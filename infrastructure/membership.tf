# The membership Cloud Function (gen2): turns a signup plus an invite code into
# a role.
#
# THIS IS THE ONLY PUBLICLY-INVOKABLE FUNCTION IN THE PROJECT. The other four
# are scheduler-only, with run.invoker restricted to a single service account.
# This one has to accept calls from the app, so it is deliberately open at the
# network edge and gated in code instead:
#
#   1. a Firebase ID token, verified server-side, proving the caller just
#      created an account;
#   2. an invite code, checked against invite_codes, proving they belong here.
#
# The worst an abuser achieves without a code is a junk Auth user — no club data
# is reachable, because every collection stays closed to clients.

locals {
  membership_function_dir = "${path.module}/../functions/membership"
  membership_function_files = [
    "models.py",
    "membership.py",
    "request.py",
    "function.py",
    "requirements.txt",
  ]
}

data "archive_file" "membership_source" {
  type        = "zip"
  output_path = "${path.module}/build/membership_source.zip"

  dynamic "source" {
    for_each = local.membership_function_files
    content {
      content  = file("${local.membership_function_dir}/${source.value}")
      filename = source.value
    }
  }
}

resource "google_storage_bucket_object" "membership_source" {
  # md5 in the name → a code change yields a new object → the function redeploys.
  name   = "membership/source-${data.archive_file.membership_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.membership_source.output_path
}

# --- Runtime service account (least privilege) --------------------------
resource "google_service_account" "membership" {
  account_id   = "membership"
  display_name = "Membership Cloud Function"
}

# Reads invite_codes and writes users.
resource "google_project_iam_member" "membership_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.membership.email}"
}

# Sets custom claims and reads user records. serviceAccountTokenCreator is what
# lets the Admin SDK mint and verify on this identity's behalf.
resource "google_project_iam_member" "membership_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.membership.email}"
}

resource "google_project_iam_member" "membership_firebase_auth" {
  project = var.project_id
  role    = "roles/firebaseauth.admin"
  member  = "serviceAccount:${google_service_account.membership.email}"
}

# --- The function -------------------------------------------------------
resource "google_cloudfunctions2_function" "membership" {
  name     = "membership"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "claim_membership"
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.membership_source.name
      }
    }
  }

  service_config {
    # Signup is rare and bursty. A low cap is also a crude rate limit on anyone
    # trying codes at scale.
    max_instance_count    = 3
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.membership.email
  }

  depends_on = [google_project_service.enabled]
}

# Public at the network edge — see the header. The gate is in the function.
resource "google_cloud_run_v2_service_iam_member" "membership_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.membership.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "membership_function_uri" {
  description = "The signup endpoint the app calls after creating an account."
  value       = google_cloudfunctions2_function.membership.service_config[0].uri
}
