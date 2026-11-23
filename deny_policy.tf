locals {
  tf_bootstrap_principal = "principal://iam.googleapis.com/projects/-/serviceAccounts/${var.tf_bootstrap_email}"
  tf_plan_principal      = "principal://iam.googleapis.com/projects/-/serviceAccounts/${var.tf_plan_email}"

  # Allow policies still decide which secrets each of them reads
  secret_reader_principals = toset(concat(
    [local.tf_bootstrap_principal, local.tf_plan_principal, "principal://iam.googleapis.com/projects/-/serviceAccounts/${google_service_account.api_manager.email}"],
    [for accessor in values(merge(local.gemini_api_key_accessors, local.api_keys_secret_accessors)) : "principal://iam.googleapis.com/projects/-/serviceAccounts/${accessor.email}"],
  ))
}

resource "google_iam_deny_policy" "api_management" {
  parent       = urlencode("cloudresourcemanager.googleapis.com/projects/${google_project_service.api_management["iam.googleapis.com"].project}")
  name         = "${local.common_short_name}-api-keys-protection"
  display_name = "API keys and secrets protection"

  rules {
    description = "Only tf-bootstrap manages the API keys"

    deny_rule {
      denied_principals    = ["principalSet://goog/public:all"]
      exception_principals = [local.tf_bootstrap_principal]
      denied_permissions = [
        # keep-sorted start
        "apikeys.googleapis.com/apiKeys.regenerate",
        "apikeys.googleapis.com/apiKeys.revert",
        "apikeys.googleapis.com/keys.create",
        "apikeys.googleapis.com/keys.delete",
        "apikeys.googleapis.com/keys.undelete",
        "apikeys.googleapis.com/keys.update",
        # keep-sorted end
      ]
    }
  }

  rules {
    description = "Only the Terraform service accounts read the API keys' key strings"

    deny_rule {
      denied_principals    = ["principalSet://goog/public:all"]
      exception_principals = [local.tf_bootstrap_principal, local.tf_plan_principal]
      denied_permissions   = ["apikeys.googleapis.com/keys.getKeyString"]
    }
  }

  rules {
    description = "Only tf-bootstrap manages the secrets and their access policies"

    deny_rule {
      denied_principals    = ["principalSet://goog/public:all"]
      exception_principals = [local.tf_bootstrap_principal]
      denied_permissions = [
        # keep-sorted start
        "secretmanager.googleapis.com/secrets.create",
        "secretmanager.googleapis.com/secrets.delete",
        "secretmanager.googleapis.com/secrets.setIamPolicy",
        "secretmanager.googleapis.com/secrets.update",
        "secretmanager.googleapis.com/versions.add",
        "secretmanager.googleapis.com/versions.destroy",
        "secretmanager.googleapis.com/versions.disable",
        "secretmanager.googleapis.com/versions.enable",
        # keep-sorted end
      ]
    }
  }

  rules {
    description = "Only the Terraform service accounts, the API keys manager and the declared accessors read the secrets"

    deny_rule {
      denied_principals    = ["principalSet://goog/public:all"]
      exception_principals = local.secret_reader_principals
      denied_permissions   = ["secretmanager.googleapis.com/versions.access"]
    }
  }
}
