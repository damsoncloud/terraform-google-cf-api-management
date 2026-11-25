locals {
  gemini_api_keys = {
    for purpose, key in var.gemini_api_keys : purpose => merge(key, {
      name       = "${local.environments[key.environment_name]}-${var.region}-geminiapi-${purpose}"
      short_name = local.environments[key.environment_name]
    })
  }

  gemini_api_key_accessors = merge([
    for purpose, key in var.gemini_api_keys : {
      for email in key.accessor_service_accounts_emails : "${purpose}/${email}" => { purpose = purpose, email = email }
    }
  ]...)
}

resource "google_apikeys_key" "gemini_api" {
  provider = google.api_keys
  for_each = local.gemini_api_keys

  project               = google_project_service.api_management["apikeys.googleapis.com"].project
  name                  = each.value.name
  display_name          = each.value.display_name
  service_account_email = google_service_account.gemini_api[each.value.environment_name].email

  restrictions {
    api_targets {
      service = google_project_service.api_management["generativelanguage.googleapis.com"].service
    }

    dynamic "server_key_restrictions" {
      for_each = each.value.server_key_restrictions[*]

      content {
        allowed_ips = server_key_restrictions.value.allowed_ips
      }
    }
  }

  depends_on = [google_project_iam_member.api_keys_billing]
}

# Tagged with the key's environment, so that only the development keys are readable by the API keys manager
resource "google_secret_manager_regional_secret" "gemini_api" {
  for_each = local.gemini_api_keys

  project   = google_project_service.api_management["secretmanager.googleapis.com"].project
  secret_id = each.value.name
  location  = var.region
  labels    = merge(each.value.labels, { environment = each.value.short_name })

  tags = {
    (var.environment_tag_key) = var.environment_tag_values[each.value.environment_name]
  }
}

resource "google_secret_manager_regional_secret_version" "gemini_api" {
  for_each = local.gemini_api_keys

  secret      = google_secret_manager_regional_secret.gemini_api[each.key].id
  secret_data = google_apikeys_key.gemini_api[each.key].key_string
}

resource "google_secret_manager_regional_secret_iam_member" "gemini_api" {
  for_each = local.gemini_api_key_accessors

  project   = google_secret_manager_regional_secret.gemini_api[each.value.purpose].project
  location  = google_secret_manager_regional_secret.gemini_api[each.value.purpose].location
  secret_id = google_secret_manager_regional_secret.gemini_api[each.value.purpose].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.email}"
}
