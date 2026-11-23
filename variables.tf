variable "domain" {
  description = "Domain of the organisation's groups."
  type        = string
}

variable "folders" {
  description = "The folders by folder name, e.g. the `folders` output of cf-hierarchy: `id`, the resource name (`folders/<id>`); `short_name`, the environment's short name, null for folders other than environments; `common`, whether it is the common environment. Each environment gets a Gemini API keys service account; the common environment's short name prefixes the resources' names and names its SREs group."
  type = map(object({
    id         = string
    short_name = optional(string)
    common     = optional(bool, false)
  }))

  validation {
    condition     = length([for folder in values(var.folders) : folder if folder.common && folder.short_name != null]) == 1 && length([for folder in values(var.folders) : folder if folder.common]) == 1
    error_message = "Exactly one folder must be the common environment, with a short name."
  }
}

variable "environment_tag_key" {
  description = "ID of the `environment` tag key (`tagKeys/<id>`), e.g. the `environment_tag_key` output of cf-hierarchy."
  type        = string

  validation {
    condition     = can(regex("^tagKeys/[0-9]+$", var.environment_tag_key))
    error_message = "The environment_tag_key must be `tagKeys/<id>`."
  }
}

variable "environment_tag_values" {
  description = "IDs of the `environment` tag values (`tagValues/<id>`) by folder name, e.g. the `environment_tag_values` output of cf-hierarchy. Only the secrets tagged `development` are readable by the API keys' accessors."
  type        = map(string)

  validation {
    condition = (
      alltrue([for value in values(var.environment_tag_values) : can(regex("^tagValues/[0-9]+$", value))]) &&
      alltrue([for name in concat(["development"], [for name, folder in var.folders : name if folder.short_name != null]) : contains(keys(var.environment_tag_values), name)])
    )
    error_message = "The environment_tag_values must be `tagValues/<id>`, for the `development` environment and every environment of `folders`."
  }
}

variable "api_management_project_id" {
  description = "ID of the API Management Hub project, e.g. the `api_management_project_id` output of cf-organization."
  type        = string
}

variable "tf_bootstrap_email" {
  description = "Email of the `tf-bootstrap` service account applying the module, e.g. the `tf_bootstrap_email` output of cf-bootstrap, decrypting the KMS-encrypted values of the API keys' secrets."
  type        = string
}

variable "tf_plan_email" {
  description = "Email of the `tf-plan` service account planning the module, e.g. the `tf_plan_email` output of cf-bootstrap, decrypting the KMS-encrypted values and reading the API keys' key strings and secrets when planning."
  type        = string
}

variable "region" {
  description = "Region of the KMS key and the secrets, part of their names."
  type        = string
  default     = "europe-west4"
  nullable    = false
}

variable "kms_key_rotation_period" {
  description = "Rotation period of the KMS key, in seconds with an `s` suffix; earlier key versions keep decrypting the values encrypted with them."
  type        = string
  default     = "7776000s"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+s$", var.kms_key_rotation_period)) && try(tonumber(trimsuffix(var.kms_key_rotation_period, "s")) >= 86400, false)
    error_message = "The kms_key_rotation_period must be at least 86400s (1 day)."
  }
}

variable "sres_group_suffix" {
  description = "Suffix of the common environment's SREs group (`gcp-<common short name>-<suffix>`), encrypting the values of the API keys' secrets."
  type        = string
  default     = "sres"
  nullable    = false
}

variable "api_keys_accessors_group_name" {
  description = "Name of the group impersonating the API keys manager service account to read the development environment's secrets, without the domain."
  type        = string
  default     = "gcp-api-keys-accessors"
  nullable    = false
}

variable "gemini_api_keys" {
  description = <<-EOT
  Gemini API keys by purpose, each restricted to the Gemini API, bound to its environment's service account and stored in a regional secret tagged with its environment.
  The key and the secret are named `<environment short name>-<region>-geminiapi-<purpose>`. Each key has:
  `environment_name`, the folder name of its environment;
  `labels` of the secret, following the labelling strategy of the customer design document: at least `department` and `owner`, e.g. a team name or an email with `_at_` and `_`
  in place of `@` and dots; the `environment` label is set to the environment's short name;
  `display_name` of the key;
  `accessor_service_accounts_emails`, the service accounts reading the secret;
  `server_key_restrictions`, the IP addresses or ranges allowed to use the key.
  EOT
  type = map(object({
    environment_name                 = string
    labels                           = map(string)
    display_name                     = optional(string)
    accessor_service_accounts_emails = optional(set(string), [])
    server_key_restrictions = optional(object({
      allowed_ips = list(string)
    }))
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in values(var.gemini_api_keys) : contains([for name, folder in var.folders : name if folder.short_name != null], key.environment_name)])
    error_message = "The environment_name of each Gemini API key must be an environment of `folders`."
  }

  validation {
    condition = alltrue([for purpose, key in var.gemini_api_keys :
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", purpose)) &&
      length("${try(var.folders[key.environment_name].short_name, "")}-${var.region}-geminiapi-${purpose}") <= 63
    ])
    error_message = "Gemini API key purposes must be lowercase letters, digits and hyphens, starting and ending with a letter or a digit, and `<environment short name>-<region>-geminiapi-<purpose>` must not exceed 63 characters."
  }

  validation {
    condition     = alltrue([for key in values(var.gemini_api_keys) : contains(keys(key.labels), "department") && contains(keys(key.labels), "owner")])
    error_message = "The labels of each Gemini API key must include department and owner."
  }

  validation {
    condition = alltrue(flatten([for key in values(var.gemini_api_keys) : [for name, value in key.labels :
      can(regex("^[\\p{Ll}\\p{Lo}][\\p{Ll}\\p{Lo}\\p{N}_-]{0,62}$", name)) && can(regex("^[\\p{Ll}\\p{Lo}\\p{N}_-]{0,63}$", value))
    ]]))
    error_message = "Label keys must be 1-63 and values 0-63 lowercase letters, digits, underscores or hyphens, keys starting with a letter, e.g. `team_at_example_com` for an email."
  }
}

variable "api_keys_secrets" {
  description = <<-EOT
  Secrets of the API keys other than Gemini's, by purpose, each in a regional secret named `<environment short name>-<region>-<purpose>` and tagged with its environment.
  Each secret has:
  `environment_name`, the folder name of its environment;
  `labels` of the secret, as those of `gemini_api_keys`;
  `encrypted_secret_data`, the base64-encoded value, encrypted with the `kms_crypto_key` and base64-encoded again, as described in the README;
  `encrypted_secret_data_version`, incremented to write a changed value as a new secret version, as changes of the value alone are ignored;
  `accessor_service_accounts_emails`, the service accounts reading the secret.
  tf-bootstrap decrypts the values when writing them, and tf-plan when planning, so the base64-encoded values are stored in the Terraform state.
  EOT
  type = map(object({
    environment_name                 = string
    labels                           = map(string)
    encrypted_secret_data            = string
    encrypted_secret_data_version    = number
    accessor_service_accounts_emails = optional(set(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for secret in values(var.api_keys_secrets) : contains([for name, folder in var.folders : name if folder.short_name != null], secret.environment_name)])
    error_message = "The environment_name of each API key secret must be an environment of `folders`."
  }

  validation {
    condition = alltrue([for purpose, secret in var.api_keys_secrets :
      can(regex("^[a-zA-Z0-9_-]+$", purpose)) && !startswith(purpose, "geminiapi-") &&
      length("${try(var.folders[secret.environment_name].short_name, "")}-${var.region}-${purpose}") <= 255
    ])
    error_message = "API key secret purposes must be letters, digits, underscores or hyphens, must not start with `geminiapi-`, and `<environment short name>-<region>-<purpose>` must not exceed 255 characters."
  }

  validation {
    condition     = alltrue([for secret in values(var.api_keys_secrets) : can(base64decode(secret.encrypted_secret_data)) && secret.encrypted_secret_data_version >= 1])
    error_message = "The encrypted_secret_data must be base64-encoded and the encrypted_secret_data_version at least 1."
  }

  validation {
    condition     = alltrue([for secret in values(var.api_keys_secrets) : contains(keys(secret.labels), "department") && contains(keys(secret.labels), "owner")])
    error_message = "The labels of each API key secret must include department and owner."
  }

  validation {
    condition = alltrue(flatten([for secret in values(var.api_keys_secrets) : [for name, value in secret.labels :
      can(regex("^[\\p{Ll}\\p{Lo}][\\p{Ll}\\p{Lo}\\p{N}_-]{0,62}$", name)) && can(regex("^[\\p{Ll}\\p{Lo}\\p{N}_-]{0,63}$", value))
    ]]))
    error_message = "Label keys must be 1-63 and values 0-63 lowercase letters, digits, underscores or hyphens, keys starting with a letter, e.g. `team_at_example_com` for an email."
  }
}
