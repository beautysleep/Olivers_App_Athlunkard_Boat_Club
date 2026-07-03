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

output "tide_function_name" {
  description = "The tide-fetcher Cloud Function name."
  value       = google_cloudfunctions2_function.tide.name
}

output "tide_function_uri" {
  description = "HTTPS URL of the tide-fetcher function (invocable only with auth)."
  value       = google_cloudfunctions2_function.tide.service_config[0].uri
}
