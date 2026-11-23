mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "333333333333"
    }
  }

  mock_data "google_kms_secret" {
    defaults = {
      plaintext = "dmFsdWU="
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

run "gemini_api_keys" {
  variables {
    gemini_api_keys = {
      chatbot = {
        environment_name                 = "development"
        labels                           = { department = "engineering", owner = "team_at_example_com" }
        accessor_service_accounts_emails = ["chatbot@dev-chatbot-a1b2.iam.gserviceaccount.com", "ci@dev-chatbot-a1b2.iam.gserviceaccount.com"]
      }
      translation = {
        environment_name        = "production"
        labels                  = { department = "localisation", owner = "translation-team", component = "translator" }
        display_name            = "Translation service"
        server_key_restrictions = { allowed_ips = ["203.0.113.0/24"] }
      }
    }
  }

  assert {
    condition = (
      google_apikeys_key.gemini_api["translation"].name == "prod-europe-west4-geminiapi-translation" &&
      google_apikeys_key.gemini_api["translation"].display_name == "Translation service" &&
      google_apikeys_key.gemini_api["translation"].service_account_email == google_service_account.gemini_api["production"].email &&
      google_apikeys_key.gemini_api["translation"].restrictions[0].api_targets[0].service == "generativelanguage.googleapis.com" &&
      google_apikeys_key.gemini_api["translation"].restrictions[0].server_key_restrictions[0].allowed_ips == tolist(["203.0.113.0/24"]) &&
      length(google_apikeys_key.gemini_api["chatbot"].restrictions[0].server_key_restrictions) == 0
    )
    error_message = "The keys must keep the legacy names, be restricted to the Gemini API and bound to their environment's service account."
  }

  assert {
    condition = (
      google_secret_manager_regional_secret.gemini_api["chatbot"].secret_id == "dev-europe-west4-geminiapi-chatbot" &&
      google_secret_manager_regional_secret.gemini_api["chatbot"].location == "europe-west4" &&
      google_secret_manager_regional_secret.gemini_api["chatbot"].tags == tomap({ "tagKeys/200000000000" = "tagValues/200000000001" }) &&
      google_secret_manager_regional_secret.gemini_api["translation"].labels == tomap({ department = "localisation", owner = "translation-team", component = "translator", environment = "prod" }) &&
      google_secret_manager_regional_secret_version.gemini_api["chatbot"].secret_data == google_apikeys_key.gemini_api["chatbot"].key_string &&
      output.gemini_api_keys["chatbot"] == google_secret_manager_regional_secret.gemini_api["chatbot"].id
    )
    error_message = "The secrets must hold the key strings, tagged and labelled with their environment."
  }

  assert {
    condition = (
      toset(keys(google_secret_manager_regional_secret_iam_member.gemini_api)) == toset([
        "chatbot/chatbot@dev-chatbot-a1b2.iam.gserviceaccount.com",
        "chatbot/ci@dev-chatbot-a1b2.iam.gserviceaccount.com",
      ]) &&
      google_secret_manager_regional_secret_iam_member.gemini_api["chatbot/ci@dev-chatbot-a1b2.iam.gserviceaccount.com"].member == "serviceAccount:ci@dev-chatbot-a1b2.iam.gserviceaccount.com" &&
      google_secret_manager_regional_secret_iam_member.gemini_api["chatbot/ci@dev-chatbot-a1b2.iam.gserviceaccount.com"].role == "roles/secretmanager.secretAccessor"
    )
    error_message = "Only the declared service accounts must read each secret."
  }
}

run "invalid_gemini_api_keys" {
  command = plan

  variables {
    gemini_api_keys = {
      Chatbot = {
        environment_name = "legacy"
        labels           = { owner = "Team@example.com" }
      }
    }
  }

  expect_failures = [var.gemini_api_keys]
}

run "gemini_api_key_name_too_long" {
  command = plan

  variables {
    gemini_api_keys = {
      "a-purpose-long-enough-to-exceed-the-api-key-id-limit" = {
        environment_name = "production"
        labels           = { department = "engineering", owner = "team" }
      }
    }
  }

  expect_failures = [var.gemini_api_keys]
}

run "api_keys_secrets" {
  variables {
    api_keys_secrets = {
      maps_api = {
        environment_name                 = "certification"
        labels                           = { department = "engineering", owner = "team_at_example_com" }
        encrypted_secret_data            = "Y2lwaGVydGV4dA=="
        encrypted_secret_data_version    = 2
        accessor_service_accounts_emails = ["maps@cert-maps-a1b2.iam.gserviceaccount.com"]
      }
    }
  }

  assert {
    condition = (
      data.google_kms_secret.api_key["maps_api"].crypto_key == google_kms_crypto_key.api_management.id &&
      data.google_kms_secret.api_key["maps_api"].ciphertext == "Y2lwaGVydGV4dA==" &&
      google_secret_manager_regional_secret_version.api_key["maps_api"].secret_data_wo_version == "2"
    )
    error_message = "The values must be decrypted with the module's key and written as the declared version."
  }

  assert {
    condition = (
      google_secret_manager_regional_secret.api_key["maps_api"].secret_id == "cert-europe-west4-maps_api" &&
      google_secret_manager_regional_secret.api_key["maps_api"].location == "europe-west4" &&
      google_secret_manager_regional_secret.api_key["maps_api"].tags == tomap({ "tagKeys/200000000000" = "tagValues/200000000002" }) &&
      google_secret_manager_regional_secret.api_key["maps_api"].labels == tomap({ department = "engineering", owner = "team_at_example_com", environment = "cert" }) &&
      output.api_keys_secrets["maps_api"] == google_secret_manager_regional_secret.api_key["maps_api"].id
    )
    error_message = "The secrets must keep the legacy names, tagged and labelled with their environment."
  }

  assert {
    condition = (
      toset(keys(google_secret_manager_regional_secret_iam_member.api_key)) == toset(["maps_api/maps@cert-maps-a1b2.iam.gserviceaccount.com"]) &&
      google_secret_manager_regional_secret_iam_member.api_key["maps_api/maps@cert-maps-a1b2.iam.gserviceaccount.com"].member == "serviceAccount:maps@cert-maps-a1b2.iam.gserviceaccount.com" &&
      google_secret_manager_regional_secret_iam_member.api_key["maps_api/maps@cert-maps-a1b2.iam.gserviceaccount.com"].role == "roles/secretmanager.secretAccessor"
    )
    error_message = "Only the declared service accounts must read each secret."
  }
}

run "invalid_api_keys_secrets" {
  command = plan

  variables {
    api_keys_secrets = {
      "geminiapi-chatbot" = {
        environment_name              = "development"
        labels                        = { department = "engineering", owner = "team" }
        encrypted_secret_data         = "not base64!"
        encrypted_secret_data_version = 0
      }
    }
  }

  expect_failures = [var.api_keys_secrets]
}
