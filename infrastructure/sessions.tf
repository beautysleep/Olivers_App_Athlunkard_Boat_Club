# The sessions Cloud Function (gen2): propose, respond to, and cancel a
# session, and register a device for push. Four HTTPS entry points sharing
# one source bundle and one service account.
#
# Along with membership, these are the only publicly-invokable functions in
# the project — the four condition-collecting/deciding jobs are
# scheduler-only, with run.invoker restricted to a single service account.
# These have to accept calls from the app, so they are deliberately open at
# the network edge and gated in code instead: a Firebase ID token, verified
# server-side, and (for propose/respond/cancel) the role custom claim
# membership already set at signup. There is no second Firestore read for
# role — the already-verified token carries it.

locals {
  sessions_function_dir = "${path.module}/../functions/sessions"
  sessions_function_files = [
    "models.py",
    "documents.py",
    "request.py",
    "notifications.py",
    "function.py",
    "requirements.txt",
  ]
}

data "archive_file" "sessions_source" {
  type        = "zip"
  output_path = "${path.module}/build/sessions_source.zip"

  dynamic "source" {
    for_each = local.sessions_function_files
    content {
      content  = file("${local.sessions_function_dir}/${source.value}")
      filename = source.value
    }
  }
}

resource "google_storage_bucket_object" "sessions_source" {
  # md5 in the name → a code change yields a new object → the function redeploys.
  name   = "sessions/source-${data.archive_file.sessions_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.sessions_source.output_path
}

# --- Runtime service account (least privilege) --------------------------
# One account for all four entry points: they share one trust boundary
# already (the same source, the same verified-token gate), and none of them
# sets a custom claim, so — unlike membership's — this needs no
# firebaseauth.admin / serviceAccountTokenCreator.
resource "google_service_account" "sessions" {
  account_id   = "sessions"
  display_name = "Sessions Cloud Function"
}

resource "google_project_iam_member" "sessions_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.sessions.email}"
}

# --- The functions --------------------------------------------------------
resource "google_cloudfunctions2_function" "propose_session" {
  name     = "propose-session"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "propose_session"
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.sessions_source.name
      }
    }
  }

  service_config {
    # Proposing is rare and bursty, same reasoning as membership's signup.
    max_instance_count    = 3
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.sessions.email
  }

  depends_on = [google_project_service.enabled]
}

resource "google_cloudfunctions2_function" "respond_to_session" {
  name     = "respond-to-session"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "respond_to_session"
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.sessions_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 3
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.sessions.email
  }

  depends_on = [google_project_service.enabled]
}

resource "google_cloudfunctions2_function" "cancel_session" {
  name     = "cancel-session"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "cancel_session"
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.sessions_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 3
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.sessions.email
  }

  depends_on = [google_project_service.enabled]
}

resource "google_cloudfunctions2_function" "register_device_token" {
  name     = "register-device-token"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "register_device_token"
    environment_variables = {
      GOOGLE_FUNCTION_SOURCE = "function.py"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.sessions_source.name
      }
    }
  }

  service_config {
    # Called far more often than the other three (every launch/token
    # refresh), but each call is a single tiny document write.
    max_instance_count    = 3
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.sessions.email
  }

  depends_on = [google_project_service.enabled]
}

# Public at the network edge — see the header. The gate is in the code.
resource "google_cloud_run_v2_service_iam_member" "propose_session_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.propose_session.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "respond_to_session_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.respond_to_session.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "cancel_session_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.cancel_session.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "register_device_token_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.register_device_token.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "propose_session_uri" {
  description = "The propose-session endpoint the app calls after the coach picks a window and meeting time."
  value       = google_cloudfunctions2_function.propose_session.service_config[0].uri
}

output "respond_to_session_uri" {
  description = "The respond-to-session endpoint the app calls when an athlete accepts or declines."
  value       = google_cloudfunctions2_function.respond_to_session.service_config[0].uri
}

output "cancel_session_uri" {
  description = "The cancel-session endpoint the app calls when a coach cancels or pivots to land."
  value       = google_cloudfunctions2_function.cancel_session.service_config[0].uri
}

output "register_device_token_uri" {
  description = "The endpoint the app calls to register or refresh its FCM device token."
  value       = google_cloudfunctions2_function.register_device_token.service_config[0].uri
}
