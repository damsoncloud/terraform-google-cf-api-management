output "gemini_api_keys" {
  description = "IDs of the Gemini API keys' secrets, by purpose."
  value       = module.api_management.gemini_api_keys
}

output "api_manager_email" {
  description = "Email of the API keys manager, impersonated by the API keys' accessors."
  value       = module.api_management.api_manager_email
}
