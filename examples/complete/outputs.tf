output "kms_crypto_key" {
  description = "ID of the KMS key encrypting the values of the API keys' secrets."
  value       = module.api_management.kms_crypto_key
}

output "gemini_api_keys" {
  description = "IDs of the Gemini API keys' secrets, by purpose."
  value       = module.api_management.gemini_api_keys
}

output "api_keys_secrets" {
  description = "IDs of the other API keys' secrets, by purpose."
  value       = module.api_management.api_keys_secrets
}
