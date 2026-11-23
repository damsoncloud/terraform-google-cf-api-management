variable "organization_id" {
  description = "ID of the organisation."
  type        = string
}

variable "domain" {
  description = "Domain of the organisation's groups."
  type        = string
}

variable "billing_account" {
  description = "ID of the billing account."
  type        = string
}

variable "mode" {
  description = "Mode of the perimeter, including the ingress rules of the API keys' accessors: `dry_run` first, then `enforced`."
  type        = string
  default     = "dry_run"
}

variable "chatbot_service_account" {
  description = "Email of the development chatbot's service account, reading its Gemini API key."
  type        = string
}

variable "translation_service_account" {
  description = "Email of the production translation service's service account, reading its API keys."
  type        = string
}

variable "translation_egress_ip_ranges" {
  description = "IP addresses or ranges from which the translation service calls the Gemini API."
  type        = list(string)
}

variable "maps_api_key_ciphertext" {
  description = "The base64-encoded Maps API key, encrypted with the module's KMS key and base64-encoded."
  type        = string
}
