# Firebase Authentication (Identity Platform).
#
# Needed before the app can write anything: Firestore rules authorise a write by
# asking who is making it, and until now every collection has been read-only for
# clients, written by service accounts that bypass rules entirely.
#
# Email and password only. The club is a closed group — there is no self-signup
# flow and no social provider — so accounts are created deliberately rather than
# by anyone who finds the app.

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

  depends_on = [google_project_service.enabled]
}
