# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.101.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "1.15.0"
    }
  }

  # if you need save your tf state security
  #   backend "azurerm" {
  #     resource_group_name = "value"
  #     storage_account_name = "value"
  #     container_name = "value"
  #     key = "value"
  #   }

}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {
}

#Criando um grupo de Data Engineers
resource "azuread_group" "data_engineers" {
  display_name     = "Data Engineers"
  description      = "Group for Data Engineers"
  security_enabled = true
}

#Criando um grupo de Data Engineers
resource "azuread_group" "account_unity_admin" {
  display_name     = "account_unity_admin"
  description      = "Group for Admin Unity Account"
  security_enabled = true
}

# Criando os usuários
resource "azuread_user" "user1" {
  display_name        = "Minato"
  user_principal_name = "minato@douglasslealoutlook.onmicrosoft.com"
  password            = "Password1234!"
  mail_nickname       = "Minato"
  given_name          = "minato"
  job_title           = "Data Engineer"
  department          = "Engineering"
}

resource "azuread_user" "user2" {
  display_name        = "Carlao"
  user_principal_name = "carlao@douglasslealoutlook.onmicrosoft.com"
  password            = "Password5678!"
  mail_nickname       = "carlao"
  given_name          = "Carlao"
  job_title           = "Data Engineer"
  department          = "Engineering"
}

resource "azuread_user" "user3" {
  display_name        = "Narezzi"
  user_principal_name = "narezzi@douglasslealoutlook.onmicrosoft.com"
  password            = "Password5678!"
  mail_nickname       = "narezzi"
  given_name          = "Narezzi"
  job_title           = "Data Engineer"
  department          = "Engineering"
}

resource "azuread_user" "user4" {
  display_name        = "Brunno"
  user_principal_name = "brunno@douglasslealoutlook.onmicrosoft.com"
  password            = "Password5624!"
  mail_nickname       = "brunno"
  given_name          = "Brunno"
  job_title           = "account_unity_admin"
  department          = "Engineering"
}

# Adicionando os usuários ao grupo de Data Engineers
resource "azuread_group_member" "user1_member" {
  group_object_id  = azuread_group.data_engineers.id
  member_object_id = azuread_user.user1.id
}

resource "azuread_group_member" "user2_member" {
  group_object_id  = azuread_group.data_engineers.id
  member_object_id = azuread_user.user2.id
}

resource "azuread_group_member" "user3_member" {
  group_object_id  = azuread_group.data_engineers.id
  member_object_id = azuread_user.user3.id
}

resource "azuread_group_member" "user4_member" {
  group_object_id  = azuread_group.account_unity_admin.id
  member_object_id = azuread_user.user4.id
}

# Create a resource group
resource "azurerm_resource_group" "this" {
  name     = "rsg${local.suffix_concat}"
  location = var.location
  tags     = local.tags
}

# Create a storage account gen2 in resource group
resource "azurerm_storage_account" "this" {
  name                      = "sta${local.suffix_concat}"
  resource_group_name       = azurerm_resource_group.this.name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  access_tier               = "Hot"
  is_hns_enabled            = true
  shared_access_key_enabled = true
  min_tls_version           = "TLS1_2"
  tags                      = local.tags
}

# resource "azurerm_eventhub_namespace" "this" {
#   name                = "eh${local.suffix_concat}"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#   sku                 = "Standard"
#   capacity            = 1
#   tags                = local.tags
# }

resource "azurerm_databricks_workspace" "this" {
  location                    = azurerm_resource_group.this.location
  name                        = "adb${local.suffix_concat}"
  resource_group_name         = azurerm_resource_group.this.name
  sku                         = "trial"
  managed_resource_group_name = "rsg${local.suffix_concat}-workspace"
  tags                        = local.tags
}

// Provider for databricks account
provider "databricks" {
  alias      = "azure_account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = azurerm_databricks_workspace.this.workspace_id
  auth_type  = "azure-cli"
}

// Module creating UC metastore and adding users, groups and service principals to azure databricks account
module "metastore_and_users" {
  source                    = "./modules/metastore-and-users"
  databricks_workspace_name = azurerm_databricks_workspace.this.name
  account_id                = azurerm_databricks_workspace.this.workspace_id
  subscription_id           = data.azurerm_client_config.current.subscription_id
  resource_group            = azurerm_resource_group.this.name
  aad_groups                = var.aad_groups
  prefix                    = local.suffix_concat
}

locals {
  merged_user_sp = merge(module.metastore_and_users.databricks_users, module.metastore_and_users.databricks_sps)
}

locals {
  aad_groups = toset(var.aad_groups)
}

// Read group members of given groups from AzureAD every time Terraform is started
data "azuread_group" "this" {
  for_each     = local.aad_groups
  display_name = each.value
}


// Put users and service principals to their respective groups
resource "databricks_group_member" "this" {
  provider = databricks.azure_account
  for_each = toset(flatten([
    for group, details in data.azuread_group.this : [
      for member in details["members"] : jsonencode({
        group  = module.metastore_and_users.databricks_groups[details["object_id"]],
        member = local.merged_user_sp[member]
      })
    ]
  ]))
  group_id   = jsondecode(each.value).group
  member_id  = jsondecode(each.value).member
  depends_on = [module.metastore_and_users]
}

// Identity federation - adding users/groups from databricks account to workspace
resource "databricks_mws_permission_assignment" "workspace_user_groups" {
  for_each     = data.azuread_group.this
  provider     = databricks.azure_account
  workspace_id = module.metastore_and_users.databricks_workspace_id
  principal_id = module.metastore_and_users.databricks_groups[each.value["object_id"]]
  permissions  = each.key == "account_unity_admin" ? ["ADMIN"] : ["USER"]
  depends_on   = [databricks_group_member.this]
}

// Create storage credentials, external locations, catalogs, schemas and grants

// Create a container in storage account to be used by dev catalog as root storage
resource "azurerm_storage_container" "dev_catalog" {
  name                  = "dev-catalog"
  storage_account_name  = module.metastore_and_users.azurerm_storage_account_unity_catalog.name
  container_access_type = "private"
}

// Storage credential creation to be used to create external location
resource "databricks_storage_credential" "external_mi" {
  name = "external_location_mi_credential"
  azure_managed_identity {
    access_connector_id = module.metastore_and_users.azurerm_databricks_access_connector_id
  }
  owner      = "account_unity_admin"
  comment    = "Storage credential for all external locations"
  depends_on = [databricks_mws_permission_assignment.workspace_user_groups]
}

// Create external location to be used as root storage by dev catalog
resource "databricks_external_location" "dev_location" {
  name = "dev-catalog-external-location"
  url = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_container.dev_catalog.name,
  module.metastore_and_users.azurerm_storage_account_unity_catalog.name)
  credential_name = databricks_storage_credential.external_mi.id
  owner           = "account_unity_admin"
  comment         = "External location used by dev catalog as root storage"
}

// Create dev environment catalog
resource "databricks_catalog" "dev" {
  metastore_id = module.metastore_and_users.metastore_id
  name         = "dev_catalog"
  comment      = "this catalog is for dev env"
  owner        = "account_unity_admin"
  storage_root = databricks_external_location.dev_location.url
  properties = {
    purpose = "dev"
  }
  depends_on = [databricks_external_location.dev_location]
}

// Grants on dev catalog
resource "databricks_grants" "dev_catalog" {
  catalog = databricks_catalog.dev.name
  grant {
    principal  = "data_engineer"
    privileges = ["USE_CATALOG"]
  }
  grant {
    principal  = "data_scientist"
    privileges = ["USE_CATALOG"]
  }
  grant {
    principal  = "data_analyst"
    privileges = ["USE_CATALOG"]
  }
}

// Create schema for bronze datalake layer in dev env.
resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.dev.id
  name         = "bronze"
  owner        = "account_unity_admin"
  comment      = "this database is for bronze layer tables/views"
}

// Grants on bronze schema
resource "databricks_grants" "bronze" {
  schema = databricks_schema.bronze.id
  grant {
    principal  = "data_engineer"
    privileges = ["USE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "EXECUTE", "MODIFY", "SELECT"]
  }
}

// Create schema for silver datalake layer in dev env.
resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.dev.id
  name         = "silver"
  owner        = "account_unity_admin"
  comment      = "this database is for silver layer tables/views"
}

// Grants on silver schema
resource "databricks_grants" "silver" {
  schema = databricks_schema.silver.id
  grant {
    principal  = "data_engineer"
    privileges = ["USE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "EXECUTE", "MODIFY", "SELECT"]
  }
  grant {
    principal  = "data_scientist"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}

// Create schema for gold datalake layer in dev env.
resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.dev.id
  name         = "gold"
  owner        = "account_unity_admin"
  comment      = "this database is for gold layer tables/views"
}

// Grants on gold schema
resource "databricks_grants" "gold" {
  schema = databricks_schema.gold.id
  grant {
    principal  = "data_engineer"
    privileges = ["USE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "EXECUTE", "MODIFY", "SELECT"]
  }
  grant {
    principal  = "data_scientist"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = "data_analyst"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}
