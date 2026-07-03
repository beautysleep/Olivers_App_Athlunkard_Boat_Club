# Firebase enablement, Android app registration, and Firestore security rules —
# so the Flutter client can read tide data from Firestore directly.

resource "google_firebase_project" "default" {
  provider   = google-beta
  project    = var.project_id
  depends_on = [google_project_service.enabled]
}

resource "google_firebase_android_app" "app" {
  provider     = google-beta
  project      = var.project_id
  display_name = "Athlunkard Boat Club"
  package_name = "com.athlunkardboatclub.athlunkard_boat_club"
  depends_on   = [google_firebase_project.default]
}

# The generated google-services.json, written into the Android app. It is
# gitignored (not a real secret, but kept out of git per the Flutter template).
data "google_firebase_android_app_config" "app" {
  provider = google-beta
  app_id   = google_firebase_android_app.app.app_id
  project  = var.project_id
}

resource "local_file" "google_services_json" {
  filename = "${path.module}/../app/android/app/google-services.json"
  content  = base64decode(data.google_firebase_android_app_config.app.config_file_contents)
}

# --- Firestore security rules -------------------------------------------
resource "google_firebaserules_ruleset" "firestore" {
  provider = google-beta
  project  = var.project_id

  source {
    files {
      name    = "firestore.rules"
      content = file("${path.module}/firestore.rules")
    }
  }

  depends_on = [google_firebase_project.default]
}

resource "google_firebaserules_release" "firestore" {
  provider     = google-beta
  project      = var.project_id
  name         = "cloud.firestore"
  ruleset_name = google_firebaserules_ruleset.firestore.name

  depends_on = [google_firestore_database.default]
}
