# Encrypts the values of the other API keys' secrets, which tf-bootstrap decrypts when writing them to Secret Manager, and tf-plan when planning
resource "google_kms_key_ring" "api_management" {
  project  = google_project_service.api_management["cloudkms.googleapis.com"].project
  name     = local.name_prefix
  location = var.region
}

resource "google_kms_crypto_key" "api_management" {
  name            = local.name_prefix
  key_ring        = google_kms_key_ring.api_management.id
  rotation_period = var.kms_key_rotation_period
}

resource "google_kms_crypto_key_iam_binding" "encrypters" {
  crypto_key_id = google_kms_crypto_key.api_management.id
  role          = "roles/cloudkms.cryptoKeyEncrypter"
  members       = ["group:${local.sres_group}"]
}

resource "google_kms_crypto_key_iam_binding" "decrypters" {
  crypto_key_id = google_kms_crypto_key.api_management.id
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  members       = ["group:${local.sres_group}", "serviceAccount:${var.tf_bootstrap_email}", "serviceAccount:${var.tf_plan_email}"]
}
