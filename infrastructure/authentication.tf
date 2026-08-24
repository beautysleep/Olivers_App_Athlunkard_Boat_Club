# Firebase Authentication (Identity Platform).
#
# Needed before the app can write anything: Firestore rules authorise a write by
# asking who is making it, and until now every collection has been read-only for
# clients, written by service accounts that bypass rules entirely.
#
# Email and password only. The club is a closed group — there is no open signup,
# only an invite code (see invite_codes.tf) — so accounts are created
# deliberately rather than by anyone who finds the app.

# Identity Platform must be PROVISIONED before it can be CONFIGURED, and
# google_identity_platform_config only does the second. Applying without this
# leaves a project where Terraform reports the config created but the API
# answers CONFIGURATION_NOT_FOUND and every signup fails OPERATION_NOT_ALLOWED —
# which is exactly what the first apply here produced.
#
# There is no Terraform resource for the initialize call, so this is the glue.
# Safe to repeat: initialising an already-initialised project is a no-op.
resource "terraform_data" "initialize_identity_platform" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-SHELL
      set -euo pipefail

      # terraform inherits whatever PATH it was started with, which is often not
      # the shell where gcloud was installed. Failing loudly beats initialising
      # nothing and leaving a project that only breaks at the first signup.
      GCLOUD="$(command -v gcloud || echo "$HOME/google-cloud-sdk/bin/gcloud")"
      if [ ! -x "$GCLOUD" ]; then
        echo "gcloud not found; cannot initialise Identity Platform" >&2
        exit 1
      fi

      curl -sS --fail-with-body -X POST \
        -H "Authorization: Bearer $("$GCLOUD" auth print-access-token)" \
        -H "x-goog-user-project: ${var.project_id}" \
        -H "Content-Type: application/json" \
        "https://identitytoolkit.googleapis.com/v2/projects/${var.project_id}/identityPlatform:initializeAuth" \
        -d '{}' > /dev/null
    SHELL
  }

  depends_on = [google_project_service.enabled]
}

resource "google_identity_platform_config" "auth" {
  project = var.project_id

  # No anonymous or phone sign-in: an identity we cannot tie to a club member is
  # no use for deciding who may propose a session.
  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = true
      password_required = true
    }
  }

  depends_on = [
    google_project_service.enabled,
    terraform_data.initialize_identity_platform,
  ]
}
