output "kms_crypto_key" {
  description = "ID of the KMS key encrypting the values of the API keys' secrets (`projects/<project>/locations/<region>/keyRings/<name>/cryptoKeys/<name>`), e.g. for `gcloud kms encrypt --key`."
  value       = google_kms_crypto_key.api_management.id
}

output "api_manager_email" {
  description = "Email of the API keys manager service account, impersonated by the API keys' accessors."
  value       = google_service_account.api_manager.email
}

output "gemini_api_service_accounts" {
  description = "Emails of the service accounts the Gemini API keys are bound to, by environment folder name."
  value       = { for name, account in google_service_account.gemini_api : name => account.email }
}
