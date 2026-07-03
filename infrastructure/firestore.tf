# The app database. Native mode (document store) — Firestore's default and the
# right fit for the session/condition documents.
#
# WARNING: location_id is PERMANENT once the database is created. europe-west1
# per the standing region decision.
resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.enabled]
}
