locals {
  common_short_name    = one([for folder in values(var.folders) : folder.short_name if folder.common])
  name_prefix          = "${local.common_short_name}-${var.region}-cf-api_management"
  sres_group           = "gcp-${local.common_short_name}-${var.sres_group_suffix}@${var.domain}"
  api_keys_accessors   = "${var.api_keys_accessors_group_name}@${var.domain}"
  environments         = { for name, folder in var.folders : name => folder.short_name if folder.short_name != null }
  user_access_tag_name = "development"
}

# Plans read the secret versions; tf-plan's organisation roles already include apikeys.keys.getKeyString
resource "google_project_iam_member" "tf_plan" {
  project = google_project_service.api_management["secretmanager.googleapis.com"].project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.tf_plan_email}"
}

data "google_project" "api_management" {
  project_id = var.api_management_project_id
}

resource "google_project_service" "api_management" {
  for_each = toset([
    # keep-sorted start
    "apikeys.googleapis.com",
    "cloudkms.googleapis.com",
    "generativelanguage.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    # keep-sorted end
  ])

  project            = var.api_management_project_id
  service            = each.key
  disable_on_destroy = false
}
