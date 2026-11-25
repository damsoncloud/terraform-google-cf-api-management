terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.11, < 9"

      # The API Keys API bills the calling identity's project, unless a billing project is set: the caller configures this provider to bill the hub project
      configuration_aliases = [google.api_keys]
    }
  }
}
