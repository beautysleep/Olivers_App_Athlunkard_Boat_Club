# The weather-fetcher Cloud Function (gen2) and everything it needs.
#
# Mirrors the tide service (secrets.tf / cloud_functions.tf / cloud_scheduler.tf)
# but is kept in one file per the "each external data source is its own service"
# principle. Reuses the shared source bucket and already-enabled APIs.

# --- Secret: OpenWeather API key ----------------------------------------
# Terraform manages the secret RESOURCE only — the VALUE is added out-of-band
# (via gcloud, from the rotated key) so it never lands in Terraform code or state.
resource "google_secret_manager_secret" "openweather_api_key" {
  project   = var.project_id
  secret_id = "openweather-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled]
}

# --- Source archive -----------------------------------------------------
# Explicit allowlist of files — NOT source_dir-with-excludes — so .env, tests,
# fixtures, and __pycache__ can never be packaged or uploaded.
locals {
  weather_function_dir = "${path.module}/../functions/weather"
  weather_function_files = [
    "main.py",
    "models.py",
    "parse.py",
    "openweather_client.py",
    "firestore_docs.py",
    "function.py",
    "requirements.txt",
  ]
}

data "archive_file" "weather_source" {
  type        = "zip"
  output_path = "${path.module}/build/weather_source.zip"

  dynamic "source" {
    for_each = local.weather_function_files
    content {
      content  = file("${local.weather_function_dir}/${source.value}")
      filename = source.value
    }
  }
}

# Reuses the shared function-source bucket defined in cloud_functions.tf.
resource "google_storage_bucket_object" "weather_source" {
  # md5 in the name → a code change yields a new object → the function redeploys.
  name   = "weather/source-${data.archive_file.weather_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.weather_source.output_path
}

# --- Runtime service account (least privilege) --------------------------
resource "google_service_account" "weather_fetcher" {
  account_id   = "weather-fetcher"
  display_name = "Weather fetcher Cloud Function"
}

# Read/write Firestore documents.
resource "google_project_iam_member" "weather_fetcher_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.weather_fetcher.email}"
}

# Read only the OpenWeather secret (scoped to that one secret).
resource "google_secret_manager_secret_iam_member" "weather_fetcher_secret" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.openweather_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.weather_fetcher.email}"
}

# --- The function -------------------------------------------------------
resource "google_cloudfunctions2_function" "weather" {
  name     = "weather-fetcher"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "fetch_weather"
    # The entry point lives in function.py, not the buildpack's default main.py.
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.weather_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256M"
    timeout_seconds       = 120
    service_account_email = google_service_account.weather_fetcher.email

    # The OpenWeather key is injected from Secret Manager at runtime — never
    # baked into the image or the env in plain text.
    secret_environment_variables {
      key        = "OPENWEATHER_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.openweather_api_key.secret_id
      version    = "latest"
    }
  }

  depends_on = [google_project_service.enabled]
}

# --- Scheduler: every 3 hours -------------------------------------------
# Cloud Scheduler calls the function over HTTP with an OIDC token; the function
# stays private (no public access). Wind/rain is volatile, so it refreshes far
# more often than the once-daily tide job.
resource "google_service_account" "weather_scheduler" {
  account_id   = "weather-scheduler"
  display_name = "Weather scheduler invoker"
}

resource "google_cloud_run_v2_service_iam_member" "weather_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.weather.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.weather_scheduler.email}"
}

resource "google_cloud_scheduler_job" "weather_3h" {
  name      = "weather-fetch-3h"
  region    = var.region
  schedule  = "0 */3 * * *" # every 3 hours, on the hour
  time_zone = "Europe/Dublin"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.weather.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.weather_scheduler.email
      audience              = google_cloudfunctions2_function.weather.service_config[0].uri
    }
  }

  depends_on = [
    google_project_service.enabled,
    google_cloud_run_v2_service_iam_member.weather_invoker,
  ]
}
