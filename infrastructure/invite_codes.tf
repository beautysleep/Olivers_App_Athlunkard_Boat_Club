# Invite codes: the club's shared secrets, one per role.
#
# Stored in Firestore rather than in the function so they can be rotated without
# a redeploy. Clients can neither read nor write them (see firestore.rules), so
# a code cannot be enumerated from the app — only presented and checked.
#
# The values are NOT in this repository. Supply them at apply time:
#
#   terraform apply -var 'invite_codes={coach="...",athlete="...",parent="..."}'
#
# or via a gitignored .tfvars. Rotating one is a matter of changing the value
# and re-applying; the old document is destroyed and the code stops working.

variable "invite_codes" {
  description = "Signup codes per role. Anyone holding one can join as that role."
  type = object({
    coach   = string
    athlete = string
    parent  = string
  })
  sensitive = true
}

# One resource per role rather than a for_each: Terraform refuses to key
# resources off a sensitive value, because the instance key would appear in
# plan output and state — which is exactly the thing being kept secret.

resource "google_firestore_document" "invite_code_coach" {
  project     = var.project_id
  database    = google_firestore_database.default.name
  collection  = "invite_codes"
  document_id = lower(var.invite_codes.coach)

  fields = jsonencode({
    role  = { stringValue = "coach" }
    label = { stringValue = "Coaches" }
  })
}

resource "google_firestore_document" "invite_code_athlete" {
  project     = var.project_id
  database    = google_firestore_database.default.name
  collection  = "invite_codes"
  document_id = lower(var.invite_codes.athlete)

  fields = jsonencode({
    role  = { stringValue = "athlete" }
    label = { stringValue = "Athletes" }
  })
}

resource "google_firestore_document" "invite_code_parent" {
  project     = var.project_id
  database    = google_firestore_database.default.name
  collection  = "invite_codes"
  document_id = lower(var.invite_codes.parent)

  fields = jsonencode({
    role  = { stringValue = "parent" }
    label = { stringValue = "Parents" }
  })
}
