module "hierarchy" {
  source  = "damsoncloud/cf-hierarchy/google"
  version = "0.2.0"

  organization_id = var.organization_id
}

module "bootstrap" {
  source  = "damsoncloud/cf-bootstrap/google"
  version = "0.7.0"

  organization_id = var.organization_id
  folders         = module.hierarchy.folders
  billing_account = var.billing_account
}

module "organization" {
  source  = "damsoncloud/cf-organization/google"
  version = "0.3.0"

  organization_id     = var.organization_id
  domain              = var.domain
  environment_tag_key = module.hierarchy.environment_tag_key_namespaced_name
  folders             = module.hierarchy.folders
  billing_account     = var.billing_account

  bootstrap_project_id            = module.bootstrap.project_id
  tf_bootstrap_email              = module.bootstrap.tf_bootstrap_email
  tf_bootstrap_organization_roles = module.bootstrap.tf_bootstrap_organization_roles
  tf_plan_email                   = module.bootstrap.tf_plan_email
  tf_plan_organization_roles      = module.bootstrap.tf_plan_organization_roles
  tf_environment_emails           = module.bootstrap.tf_environment_emails
}

module "vpc_service_controls" {
  source  = "damsoncloud/cf-organization/google//modules/vpc-service-controls"
  version = "0.3.0"

  organization_id = var.organization_id
  mode            = var.mode
  projects = {
    bootstrap      = module.bootstrap.project_number
    observability  = module.organization.observability_project_number
    api_management = module.organization.api_management_project_number
  }
  deployers = concat(
    [module.bootstrap.tf_bootstrap_email, module.bootstrap.tf_plan_email],
    values(module.bootstrap.tf_environment_emails),
  )
  groups = module.organization.perimeter_groups
}

module "api_management" {
  source = "../.."

  domain                    = var.domain
  folders                   = module.hierarchy.folders
  environment_tag_key       = module.hierarchy.environment_tag_key
  environment_tag_values    = module.hierarchy.environment_tag_values
  api_management_project_id = module.organization.api_management_project_id
  tf_bootstrap_email        = module.bootstrap.tf_bootstrap_email
  tf_plan_email             = module.bootstrap.tf_plan_email

  gemini_api_keys = {
    # Read by the developers through the API keys manager, and by the chatbot's service account
    chatbot = {
      environment_name                 = "development"
      labels                           = { component = "chatbot", department = "engineering", owner = "jane_doe_at_example_com" }
      display_name                     = "Chatbot (development)"
      accessor_service_accounts_emails = [var.chatbot_service_account]
    }
    # Usable from the backend's egress addresses only
    translation = {
      environment_name                 = "production"
      labels                           = { component = "translation", department = "localisation", owner = "team-translation" }
      display_name                     = "Translation service"
      accessor_service_accounts_emails = [var.translation_service_account]
      server_key_restrictions          = { allowed_ips = var.translation_egress_ip_ranges }
    }
  }

  # Values encrypted by the SREs with the kms_crypto_key output, as described in the module's README
  api_keys_secrets = {
    maps_api = {
      environment_name                 = "production"
      labels                           = { component = "translation", department = "localisation", owner = "team-translation" }
      encrypted_secret_data            = var.maps_api_key_ciphertext
      encrypted_secret_data_version    = 1
      accessor_service_accounts_emails = [var.translation_service_account]
    }
  }

  vpc_service_controls = {
    perimeter_name = module.vpc_service_controls.perimeter_name
    mode           = var.mode
  }
}
