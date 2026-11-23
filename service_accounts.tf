# Impersonated by the API keys' accessors to read the development environment's secrets only (customer design document, Access to the API Keys)
resource "google_service_account" "api_manager" {
  project      = google_project_service.api_management["iam.googleapis.com"].project
  account_id   = "${local.common_short_name}-api-manager"
  display_name = "API keys manager"
  description  = "Reads the secrets of the development environment's API keys, impersonated by the ${local.api_keys_accessors} group."
}

resource "google_project_iam_member" "api_manager" {
  project = google_service_account.api_manager.project
  role    = "roles/secretmanager.secretAccessor"
  member  = google_service_account.api_manager.member

  condition {
    title      = "Development secrets only"
    expression = "resource.matchTagId('${var.environment_tag_key}', '${var.environment_tag_values[local.user_access_tag_name]}')"
  }
}

data "google_iam_policy" "api_manager" {
  binding {
    role    = "roles/iam.serviceAccountTokenCreator"
    members = ["group:${local.api_keys_accessors}"]
  }
}

resource "google_service_account_iam_policy" "api_manager" {
  service_account_id = google_service_account.api_manager.name
  policy_data        = data.google_iam_policy.api_manager.policy_data
}

# The Gemini API keys are bound to their environment's service account
resource "google_service_account" "gemini_api" {
  for_each = local.environments

  project      = google_project_service.api_management["iam.googleapis.com"].project
  account_id   = "${each.value}-geminiapi-keys"
  display_name = "Gemini API keys of the ${each.key} environment"
}

resource "google_tags_tag_binding" "gemini_api" {
  for_each = google_service_account.gemini_api

  parent    = "//iam.googleapis.com/projects/${data.google_project.api_management.number}/serviceAccounts/${each.value.unique_id}"
  tag_value = var.environment_tag_values[each.key]
}
