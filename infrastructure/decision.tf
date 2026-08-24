# The decision-engine Cloud Function (gen2) and everything it needs.
#
# Mirrors weather.tf / water_release.tf. The difference from the other three is
# that this service reads no external source: its inputs are the collections the
# fetchers already write, so it needs no secret and no egress — only Firestore.

# --- Source archive -----------------------------------------------------
# Explicit allowlist of files — NOT source_dir-with-excludes — so tests,
# fixtures, and __pycache__ can never be packaged or uploaded.
locals {
  decision_function_dir = "${path.module}/../functions/decision"
  decision_function_files = [
    "main.py",
    "models.py",
    "engine.py",
    "tide_curve.py",
    "inputs.py",
    "firestore_docs.py",
    "function.py",
    "requirements.txt",
  ]
}

data "archive_file" "decision_source" {
  type        = "zip"
  output_path = "${path.module}/build/decision_source.zip"

  dynamic "source" {
    for_each = local.decision_function_files
    content {
      content  = file("${local.decision_function_dir}/${source.value}")
      filename = source.value
    }
  }
}

# Reuses the shared function-source bucket defined in cloud_functions.tf.
resource "google_storage_bucket_object" "decision_source" {
  # md5 in the name → a code change yields a new object → the function redeploys.
  name   = "decision/source-${data.archive_file.decision_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.decision_source.output_path
}

# --- Runtime service account (least privilege) --------------------------
resource "google_service_account" "decision_engine" {
  account_id   = "decision-engine"
  display_name = "Decision engine Cloud Function"
}

# Reads the three source collections and writes day_ratings. No secretAccessor
# binding — there is no secret to read.
resource "google_project_iam_member" "decision_engine_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.decision_engine.email}"
}

# --- The function -------------------------------------------------------
resource "google_cloudfunctions2_function" "decision" {
  name     = "decision-engine"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "rate_days"
    # The entry point lives in function.py, not the buildpack's default main.py.
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.decision_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    # 256M as tide/weather: the work is arithmetic over a few hundred small
    # documents, with no PDF or image handling.
    available_memory      = "256M"
    timeout_seconds       = 120
    service_account_email = google_service_account.decision_engine.email
  }

  depends_on = [google_project_service.enabled]
}

# --- Scheduler: every 3 hours, quarter past ----------------------------
# Weather is the most volatile input and refreshes on the hour every 3 hours
# (weather.tf), so this runs 15 minutes behind it to rate against fresh data.
# Tide moves daily and water release daily, both well before the first run.
resource "google_service_account" "decision_scheduler" {
  account_id   = "decision-scheduler"
  display_name = "Decision engine scheduler invoker"
}

resource "google_cloud_run_v2_service_iam_member" "decision_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.decision.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.decision_scheduler.email}"
}

resource "google_cloud_scheduler_job" "decision_every_three_hours" {
  name      = "decision-rate-days"
  region    = var.region
  schedule  = "15 */3 * * *" # 15 minutes after each weather refresh
  time_zone = "Europe/Dublin"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.decision.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.decision_scheduler.email
      audience              = google_cloudfunctions2_function.decision.service_config[0].uri
    }
  }

  depends_on = [
    google_project_service.enabled,
    google_cloud_run_v2_service_iam_member.decision_invoker,
  ]
}
