locals {
  api_keys_secrets = {
    for purpose, secret in var.api_keys_secrets : purpose => merge(secret, {
      short_name = local.environments[secret.environment_name]
    })
  }

  api_keys_secret_accessors = merge([
    for purpose, secret in var.api_keys_secrets : {
      for email in secret.accessor_service_accounts_emails : "${purpose}/${email}" => { purpose = purpose, email = email }
    }
  ]...)
}

# Read at apply time while tf-bootstrap's Decrypter binding is pending, e.g. on the first apply
data "google_kms_secret" "api_key" {
  for_each = local.api_keys_secrets

  crypto_key = google_kms_crypto_key.api_management.id
  ciphertext = each.value.encrypted_secret_data

  depends_on = [google_kms_crypto_key_iam_binding.decrypters]
}

resource "google_secret_manager_regional_secret" "api_key" {
  for_each = local.api_keys_secrets

  project   = google_project_service.api_management["secretmanager.googleapis.com"].project
  secret_id = "${each.value.short_name}-${var.region}-${each.key}"
  location  = var.region
  labels    = merge(each.value.labels, { environment = each.value.short_name })

  tags = {
    (var.environment_tag_key) = var.environment_tag_values[each.value.environment_name]
  }
}

resource "google_secret_manager_regional_secret_version" "api_key" {
  for_each = local.api_keys_secrets

  secret                 = google_secret_manager_regional_secret.api_key[each.key].id
  secret_data_wo         = base64decode(data.google_kms_secret.api_key[each.key].plaintext)
  secret_data_wo_version = each.value.encrypted_secret_data_version
}

resource "google_secret_manager_regional_secret_iam_member" "api_key" {
  for_each = local.api_keys_secret_accessors

  project   = google_secret_manager_regional_secret.api_key[each.value.purpose].project
  location  = google_secret_manager_regional_secret.api_key[each.value.purpose].location
  secret_id = google_secret_manager_regional_secret.api_key[each.value.purpose].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.email}"
}
