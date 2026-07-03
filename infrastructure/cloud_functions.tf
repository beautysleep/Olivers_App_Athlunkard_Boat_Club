# The tide-fetcher Cloud Function (gen2) and everything it needs.

# --- Source archive -----------------------------------------------------
# Explicit allowlist of files — NOT source_dir-with-excludes — so .env, .venv,
# tests, and __pycache__ can never be packaged or uploaded.
locals {
  function_dir = "${path.module}/../functions/tide"
  function_files = [
    "main.py",
    "models.py",
    "calibration.py",
    "worldtides_client.py",
    "firestore_docs.py",
    "function.py",
    "requirements.txt",
  ]
}

data "archive_file" "tide_source" {
  type        = "zip"
  output_path = "${path.module}/build/tide_source.zip"

  dynamic "source" {
    for_each = local.function_files
    content {
      content  = file("${local.function_dir}/${source.value}")
      filename = source.value
    }
  }
}

# --- Source bucket ------------------------------------------------------
resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-function-source"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  depends_on = [google_project_service.enabled]
}

resource "google_storage_bucket_object" "tide_source" {
  # md5 in the name → a code change yields a new object → the function redeploys.
  name   = "tide/source-${data.archive_file.tide_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.tide_source.output_path
}

# --- Runtime service account (least privilege) --------------------------
resource "google_service_account" "tide_fetcher" {
  account_id   = "tide-fetcher"
  display_name = "Tide fetcher Cloud Function"
}

# Read/write Firestore documents.
resource "google_project_iam_member" "tide_fetcher_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.tide_fetcher.email}"
}

# Read only the WorldTides secret (scoped to that one secret).
resource "google_secret_manager_secret_iam_member" "tide_fetcher_secret" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.worldtides_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tide_fetcher.email}"
}

# --- The function -------------------------------------------------------
resource "google_cloudfunctions2_function" "tide" {
  name     = "tide-fetcher"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "fetch_tides"
    # The entry point lives in function.py, not the buildpack's default main.py.
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.tide_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256M"
    timeout_seconds       = 120
    service_account_email = google_service_account.tide_fetcher.email

    environment_variables = {
      TIDE_DAYS = "14"
    }

    # The WorldTides key is injected from Secret Manager at runtime — never
    # baked into the image or the env in plain text.
    secret_environment_variables {
      key        = "WORLDTIDES_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.worldtides_api_key.secret_id
      version    = "latest"
    }
  }

  depends_on = [google_project_service.enabled]
}
