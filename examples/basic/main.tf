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
    chatbot = {
      environment_name = "development"
      labels           = { department = "engineering", owner = "team-chatbot" }
    }
  }
}
