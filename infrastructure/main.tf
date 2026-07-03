# Provider and project wiring. Kept flat (one file per concern) per the
# infrastructure README — modules/environments come later if a second
# environment justifies them.

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }

  # Remote state lives in a GCS bucket (bootstrapped once via gcloud — see the
  # infrastructure README). A backend block can't reference variables, so the
  # bucket name is literal. The bucket name isn't a secret.
  backend "gcs" {
    bucket = "farnese-atlas-tfstate"
    prefix = "infrastructure"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# APIs the project needs so far. Enabling is idempotent and free; the resources
# in the other files depend on these being on. More are added as later stages
# (Cloud Functions, Scheduler) are built.
locals {
  services = [
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
  ]
}

resource "google_project_service" "enabled" {
  for_each = toset(local.services)
  project  = var.project_id
  service  = each.value

  # Don't disable the API if this resource is destroyed — other things may rely
  # on it, and re-enabling is slow.
  disable_on_destroy = false
}
