mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "333333333333"
    }
  }

  mock_data "google_iam_policy" {
    defaults = {
      policy_data = "{}"
    }
  }
}

override_resource {
  target = google_service_account.api_manager
  values = {
    email  = "cmn-api-manager@cmn-api-management-hub-c3d4.iam.gserviceaccount.com"
    member = "serviceAccount:cmn-api-manager@cmn-api-management-hub-c3d4.iam.gserviceaccount.com"
    name   = "projects/cmn-api-management-hub-c3d4/serviceAccounts/cmn-api-manager@cmn-api-management-hub-c3d4.iam.gserviceaccount.com"
  }
}

variables {
  domain = "example.com"
  folders = {
    development   = { id = "folders/100000000001", short_name = "dev" }
    certification = { id = "folders/100000000002", short_name = "cert" }
    production    = { id = "folders/100000000003", short_name = "prod" }
    common        = { id = "folders/111111111111", short_name = "cmn", common = true }
    legacy        = { id = "folders/100000000004" }
  }
  environment_tag_key = "tagKeys/200000000000"
  environment_tag_values = {
    development   = "tagValues/200000000001"
    certification = "tagValues/200000000002"
    production    = "tagValues/200000000003"
    common        = "tagValues/200000000004"
    legacy        = "tagValues/200000000005"
  }
  api_management_project_id = "cmn-api-management-hub-c3d4"
  tf_bootstrap_email        = "tf-bootstrap@cmn-cf-bootstrap-a1b2.iam.gserviceaccount.com"
}

run "kms" {
  assert {
    condition = (
      google_kms_key_ring.api_management.name == "cmn-europe-west4-cf-api_management" &&
      google_kms_key_ring.api_management.location == "europe-west4" &&
      google_kms_key_ring.api_management.project == "cmn-api-management-hub-c3d4" &&
      google_kms_crypto_key.api_management.name == "cmn-europe-west4-cf-api_management" &&
      google_kms_crypto_key.api_management.rotation_period == "7776000s" &&
      output.kms_crypto_key == google_kms_crypto_key.api_management.id
    )
    error_message = "The key ring and key must keep the legacy names in the hub project, with a 90-day rotation."
  }

  assert {
    condition = (
      google_kms_crypto_key_iam_binding.encrypters.members == toset(["group:gcp-cmn-sres@example.com"]) &&
      google_kms_crypto_key_iam_binding.decrypters.members == toset(["group:gcp-cmn-sres@example.com", "serviceAccount:tf-bootstrap@cmn-cf-bootstrap-a1b2.iam.gserviceaccount.com"])
    )
    error_message = "Only the SREs must encrypt, and only the SREs and tf-bootstrap decrypt."
  }

  assert {
    condition     = toset(keys(google_project_service.api_management)) == toset(["apikeys.googleapis.com", "cloudkms.googleapis.com", "generativelanguage.googleapis.com", "iam.googleapis.com", "secretmanager.googleapis.com"])
    error_message = "The hub's APIs must be enabled."
  }
}

run "service_accounts" {
  assert {
    condition = (
      google_service_account.api_manager.account_id == "cmn-api-manager" &&
      output.api_manager_email == "cmn-api-manager@cmn-api-management-hub-c3d4.iam.gserviceaccount.com" &&
      google_project_iam_member.api_manager.role == "roles/secretmanager.secretAccessor" &&
      google_project_iam_member.api_manager.condition[0].expression == "resource.matchTagId('tagKeys/200000000000', 'tagValues/200000000001')" &&
      one(data.google_iam_policy.api_manager.binding).role == "roles/iam.serviceAccountTokenCreator" &&
      one(data.google_iam_policy.api_manager.binding).members == toset(["group:gcp-api-keys-accessors@example.com"])
    )
    error_message = "The API keys manager must read the development secrets only, impersonated by the accessors group only."
  }

  assert {
    condition = (
      toset(keys(google_service_account.gemini_api)) == toset(["development", "certification", "production", "common"]) &&
      google_service_account.gemini_api["production"].account_id == "prod-geminiapi-keys" &&
      google_tags_tag_binding.gemini_api["production"].tag_value == "tagValues/200000000003" &&
      startswith(google_tags_tag_binding.gemini_api["production"].parent, "//iam.googleapis.com/projects/333333333333/serviceAccounts/")
    )
    error_message = "Each environment, not legacy, must get a Gemini API keys service account tagged with its environment."
  }
}

run "invalid_inputs" {
  command = plan

  variables {
    folders                 = { common = { id = "folders/111111111111" } }
    environment_tag_key     = "environment"
    kms_key_rotation_period = "3600s"
  }

  expect_failures = [var.folders, var.environment_tag_key, var.kms_key_rotation_period]
}

run "missing_tag_values" {
  command = plan

  variables {
    environment_tag_values = { common = "tagValues/200000000004", production = "prod" }
  }

  expect_failures = [var.environment_tag_values]
}
