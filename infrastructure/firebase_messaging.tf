# Push-notification setup. Grants the sessions service account permission to
# send FCM messages — fcm.googleapis.com itself is enabled in main.tf's
# service list, alongside every other API this project turns on.
#
# NOT independently verified against `gcloud iam roles list` — confirm this
# role name at apply time. A wrong role name fails silently at send-time
# (messaging.send raises PERMISSION_DENIED), not at `terraform plan`.
resource "google_project_iam_member" "sessions_messaging" {
  project = var.project_id
  role    = "roles/firebasecloudmessaging.admin"
  member  = "serviceAccount:${google_service_account.sessions.email}"
}
