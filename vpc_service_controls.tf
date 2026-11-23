locals {
  perimeter_enabled  = var.vpc_service_controls != null
  perimeter_enforced = local.perimeter_enabled && try(var.vpc_service_controls.mode, null) == "enforced"

  secret_accessors = sort(distinct([for accessor in values(merge(local.gemini_api_key_accessors, local.api_keys_secret_accessors)) : "serviceAccount:${accessor.email}"]))

  # Flows into the hub from outside the perimeter, by rule title; neither service supports method selectors
  perimeter_ingress_rules = !local.perimeter_enabled ? {} : merge(
    {
      "API keys accessors impersonating the API keys manager" = {
        identities = ["group:${local.api_keys_accessors}"]
        service    = "iamcredentials.googleapis.com"
      }
      "API keys manager reading the development secrets" = {
        identities = [google_service_account.api_manager.member]
        service    = "secretmanager.googleapis.com"
      }
    },
    length(local.secret_accessors) == 0 ? {} : {
      "API keys secrets accessors" = {
        identities = local.secret_accessors
        service    = "secretmanager.googleapis.com"
      }
    },
  )
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "rules" {
  for_each = local.perimeter_enforced ? local.perimeter_ingress_rules : {}

  perimeter = var.vpc_service_controls.perimeter_name
  title     = each.key

  ingress_from {
    identities = each.value.identities

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = ["projects/${data.google_project.api_management.number}"]

    operations {
      service_name = each.value.service

      method_selectors {
        method = "*"
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "rules" {
  for_each = local.perimeter_ingress_rules

  perimeter = var.vpc_service_controls.perimeter_name
  title     = each.key

  ingress_from {
    identities = each.value.identities

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = ["projects/${data.google_project.api_management.number}"]

    operations {
      service_name = each.value.service

      method_selectors {
        method = "*"
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
