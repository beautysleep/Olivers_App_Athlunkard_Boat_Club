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
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
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

  # identitytoolkit refuses application default credentials without a quota
  # project, and bills the call to Google's own project number instead of ours.
  # These two send our project as the quota consumer, which is what makes
  # google_identity_platform_config work at all under ADC.
  user_project_override = true
  billing_project       = var.project_id
}

# Firebase resources (project/app registration) live in the google-beta provider.
provider "google-beta" {
  project = var.project_id
  region  = var.region

  user_project_override = true
  billing_project       = var.project_id
}

# APIs the project needs so far. Enabling is idempotent and free; the resources
# in the other files depend on these being on. More are added as later stages
# (Cloud Functions, Scheduler) are built.
locals {
  services = [
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudscheduler.googleapis.com",
    "eventarc.googleapis.com",
    "firebase.googleapis.com",
    "firebaserules.googleapis.com",
    # Firebase Auth. Sessions are the first thing the *app* writes, and a
    # Firestore rule can only authorise a write against an identity.
    "identitytoolkit.googleapis.com",
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
