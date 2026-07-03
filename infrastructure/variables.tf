variable "project_id" {
  type        = string
  description = "GCP project id."
  default     = "farnese-atlas"
}

variable "region" {
  type        = string
  description = "Default region and Firestore location. europe-west1 (Belgium) for EU legal alignment; avoid UK regions."
  default     = "europe-west1"
}
