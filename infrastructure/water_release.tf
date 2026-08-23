# The water-release-fetcher Cloud Function (gen2) and everything it needs.
#
# Mirrors weather.tf, kept in one file per the "each external data source is
# its own service" principle. Reuses the shared source bucket and already-
# enabled APIs.
#
# Unlike tide/weather, this source needs NO secret: ESB publishes the three
# hydrometric PDFs as public downloads (over plain HTTP — esbhydro.ie has no
# HTTPS listener). So there is no google_secret_manager_secret resource and no
# secretAccessor IAM binding here — a deliberate difference from secrets.tf /
# weather.tf, not an omission.

# --- Source archive -----------------------------------------------------
# Explicit allowlist of files — NOT source_dir-with-excludes — so tests,
# fixtures, and __pycache__ can never be packaged or uploaded.
locals {
  water_release_function_dir = "${path.module}/../functions/water_release"
  water_release_function_files = [
    "main.py",
    "models.py",
    "esbhydro_client.py",
    "parse.py",
    "firestore_docs.py",
    "function.py",
    "requirements.txt",
  ]
}

data "archive_file" "water_release_source" {
  type        = "zip"
  output_path = "${path.module}/build/water_release_source.zip"

  dynamic "source" {
    for_each = local.water_release_function_files
    content {
      content  = file("${local.water_release_function_dir}/${source.value}")
      filename = source.value
    }
  }
}

# Reuses the shared function-source bucket defined in cloud_functions.tf.
resource "google_storage_bucket_object" "water_release_source" {
  # md5 in the name → a code change yields a new object → the function redeploys.
  name   = "water_release/source-${data.archive_file.water_release_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.water_release_source.output_path
}

# --- Runtime service account (least privilege) --------------------------
resource "google_service_account" "water_release_fetcher" {
  account_id   = "water-release-fetcher"
  display_name = "Water release fetcher Cloud Function"
}

# Read/write Firestore documents. No secretAccessor binding — no secret to read.
resource "google_project_iam_member" "water_release_fetcher_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.water_release_fetcher.email}"
}

# --- The function -------------------------------------------------------
resource "google_cloudfunctions2_function" "water_release" {
  name     = "water-release-fetcher"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "fetch_water_release"
    # The entry point lives in function.py, not the buildpack's default main.py.
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.water_release_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    # Higher than tide/weather's 256M: pdfplumber (+ its pdfminer.six/Pillow/
    # pypdfium2 transitive deps) has a heavier footprint than requests+json.
    # Unvalidated guess — check real memory usage on first deploy.
    available_memory      = "512M"
    timeout_seconds       = 120
    service_account_email = google_service_account.water_release_fetcher.email

    # No secret_environment_variables block — nothing to inject.
  }

  depends_on = [google_project_service.enabled]
}

# --- Scheduler: daily, 1h after ESB's observed 09:00 reading time -------
# Cloud Scheduler calls the function over HTTP with an OIDC token; the function
# stays private (no public access). All three PDFs update once daily; the flow
# tables (07/08) carry their own 09:00:00 reading timestamp, so 10:00 gives a
# buffer. PDF 01's own refresh cadence is less certain (observed to lag by a
# day) — a second daily run is a cheap option to revisit once real timing data
# accumulates.
resource "google_service_account" "water_release_scheduler" {
  account_id   = "water-release-scheduler"
  display_name = "Water release scheduler invoker"
}

resource "google_cloud_run_v2_service_iam_member" "water_release_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.water_release.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.water_release_scheduler.email}"
}

resource "google_cloud_scheduler_job" "water_release_daily" {
  name      = "water-release-fetch-daily"
  region    = var.region
  schedule  = "0 10 * * *" # daily at 10:00, 1h after ESB's observed 09:00 update
  time_zone = "Europe/Dublin"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.water_release.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.water_release_scheduler.email
      audience              = google_cloudfunctions2_function.water_release.service_config[0].uri
    }
  }

  depends_on = [
    google_project_service.enabled,
    google_cloud_run_v2_service_iam_member.water_release_invoker,
  ]
}
