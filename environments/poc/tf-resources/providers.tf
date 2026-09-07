provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  use_cli         = true

  features {
    log_analytics_workspace {
      permanently_delete_on_destroy = false
    }
  }
}

provider "random" {}
provider "time" {}

terraform {
  # Local state (terraform.tfstate in this directory, git-ignored).
  # Single operator, no remote backend / locking.

  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}
