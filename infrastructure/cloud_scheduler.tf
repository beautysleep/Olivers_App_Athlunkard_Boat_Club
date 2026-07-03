# Daily trigger for the tide fetcher. Cloud Scheduler calls the function over
# HTTP with an OIDC token; the function stays private (no public access).

resource "google_service_account" "tide_scheduler" {
  account_id   = "tide-scheduler"
  display_name = "Tide scheduler invoker"
}

# Allow the scheduler SA to invoke the function (gen2 runs on Cloud Run, so the
# invoke permission is on the underlying Cloud Run service of the same name).
resource "google_cloud_run_v2_service_iam_member" "tide_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.tide.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.tide_scheduler.email}"
}

resource "google_cloud_scheduler_job" "tide_daily" {
  name      = "tide-fetch-daily"
  region    = var.region
  schedule  = "0 4 * * *" # 04:00 daily
  time_zone = "Europe/Dublin"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.tide.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.tide_scheduler.email
      audience              = google_cloudfunctions2_function.tide.service_config[0].uri
    }
  }

  depends_on = [
    google_project_service.enabled,
    google_cloud_run_v2_service_iam_member.tide_invoker,
  ]
}
