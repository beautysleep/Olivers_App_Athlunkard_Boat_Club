output "firestore_database" {
  description = "The Firestore database name."
  value       = google_firestore_database.default.name
}

output "firestore_location" {
  description = "The (permanent) Firestore location."
  value       = google_firestore_database.default.location_id
}

output "worldtides_secret_id" {
  description = "Secret Manager secret holding the WorldTides API key."
  value       = google_secret_manager_secret.worldtides_api_key.secret_id
}
