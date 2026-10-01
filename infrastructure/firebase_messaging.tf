# Push-notification setup. Grants the sessions service account permission to
# send FCM messages — fcm.googleapis.com itself is enabled in main.tf's
# service list, alongside every other API this project turns on.
#
# Role name verified against `gcloud iam roles list` on 2026-10-01 — the full
# set is firebasecloudmessaging.{admin,viewer} plus the legacy per-topic
# cloudmessaging.editor. `admin` is scoped to the FCM API (not the whole
# project) and is the standard role for a service account that calls
# messaging.send via the Admin SDK.
resource "google_project_iam_member" "sessions_messaging" {
  project = var.project_id
  role    = "roles/firebasecloudmessaging.admin"
  member  = "serviceAccount:${google_service_account.sessions.email}"
}
