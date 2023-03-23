terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.3.0"
    }
  }
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "test" {
  name     = "dscott-test-rg"
  location = "East US"
}

module "aro_network" {
  source = "../"

  resource_group = azurerm_resource_group.test.name
  name_prefix    = "dscott-test"

  depends_on = [
    azurerm_resource_group.test
  ]
}
