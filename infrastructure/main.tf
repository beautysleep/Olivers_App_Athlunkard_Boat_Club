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
