# Container for the WorldTides API key. Terraform manages the secret RESOURCE
# only — the secret VALUE is added out-of-band (via gcloud, from
# functions/tide/.env) so the key never lands in Terraform code or state.
resource "google_secret_manager_secret" "worldtides_api_key" {
  project   = var.project_id
  secret_id = "worldtides-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled]
}
