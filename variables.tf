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
