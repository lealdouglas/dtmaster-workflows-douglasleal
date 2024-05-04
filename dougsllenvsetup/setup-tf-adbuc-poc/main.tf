terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # version = "=21.90.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "=1.15.0"
    }
  }
}

locals {
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "this" {
  name = local.resource_group
}

provider "azurerm" {
  features {}
}


data "azurerm_databricks_workspace" "this" {
  name                = local.databricks_workspace_name
  resource_group_name = local.resource_group
}

locals {
  databricks_workspace_host = data.azurerm_databricks_workspace.this.workspace_url
  databricks_workspace_id   = data.azurerm_databricks_workspace.this.workspace_id
}

// Provider for databricks workspace
provider "databricks" {
  host = local.databricks_workspace_host
}

// Provider for databricks account
provider "databricks" {
  alias      = "azure_account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.account_id
  auth_type  = "azure-cli"
}

// Module creating UC metastore and adding users, groups and service principals to azure databricks account
module "metastore_and_users" {
  source                    = "./modules/adb-metastore-and-users"
  aad_groups                = var.aad_groups
  account_id                = var.account_id
  subscription_id           = local.subscription_id
  databricks_workspace_name = local.databricks_workspace_name
  resource_group            = local.resource_group
  prefix                    = local.suffix_concat
}

// Module creating UC metastore and adding users, groups and service principals to azure databricks account
module "metastore" {
  source                    = "./modules/adb-metastore"
  subscription_id           = local.subscription_id
  databricks_workspace_host = local.databricks_workspace_host
  databricks_workspace_id   = local.databricks_workspace_id
  account_id                = var.account_id
  aad_groups                = var.aad_groups
  metastore_id              = module.metastore_and_users.metastore_id
  connector_id              = module.metastore_and_users.azurerm_databricks_access_connector_id
  storage_unity             = module.metastore_and_users.azurerm_storage_account_unity_catalog.name
  databricks_groups         = module.metastore_and_users.databricks_groups
  databricks_sps            = module.metastore_and_users.databricks_sps
  databricks_users          = module.metastore_and_users.databricks_users
  depends_on                = [module.metastore_and_users]
  providers = {
    databricks = databricks.azure_account
  }
}
