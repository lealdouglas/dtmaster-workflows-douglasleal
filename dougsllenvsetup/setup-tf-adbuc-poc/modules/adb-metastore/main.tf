terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # version = "=21.90.0"
    }
    databricks = {
      source = "databricks/databricks"
    }
  }
}

# // Initialize provider at Azure account-level
# provider "databricks" {
#   alias      = "azure_account"
#   host       = "https://accounts.azuredatabricks.net"
#   account_id = var.account_id
#   auth_type  = "azure-cli"
# }

resource "databricks_metastore_data_access" "first" {
  metastore_id = var.metastore_id
  name         = "the-metastore-key"
  azure_managed_identity {
    access_connector_id = var.connector_id
  }
  is_default = true
}

locals {
  merged_user_sp = merge(var.databricks_users, var.databricks_sps)
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
  # provider = databricks.azure_account
  for_each = toset(flatten([
    for group, details in data.azuread_group.this : [
      for member in details["members"] : jsonencode({
        group  = var.databricks_groups[details["object_id"]],
        member = local.merged_user_sp[member]
      })
    ]
  ]))
  group_id  = jsondecode(each.value).group
  member_id = jsondecode(each.value).member
}

// Identity federation - adding users/groups from databricks account to workspace
resource "databricks_mws_permission_assignment" "workspace_user_groups" {
  for_each = data.azuread_group.this
  # provider     = databricks.azure_account
  workspace_id = var.databricks_workspace_id
  principal_id = var.databricks_groups[each.value["object_id"]]
  permissions  = each.key == "account_unity_admin" ? ["ADMIN"] : ["USER"]
  depends_on   = [databricks_group_member.this]
}


// Create storage credentials, external locations, catalogs, schemas and grants
// Create a container in storage account to be used by dev catalog as root storage
resource "azurerm_storage_container" "dev_catalog" {
  name                  = "dev-catalog"
  storage_account_name  = var.storage_unity
  container_access_type = "private"
}

// Storage credential creation to be used to create external location
resource "databricks_storage_credential" "external_mi" {
  name = "external_location_mi_credential"
  azure_managed_identity {
    access_connector_id = var.connector_id
  }
  # owner      = "account_unity_admin"
  comment    = "Storage credential for all external locations"
  depends_on = [databricks_mws_permission_assignment.workspace_user_groups]
}

// Create external location to be used as root storage by dev catalog
// You do not have the CREATE EXTERNAL LOCATION privilege for this credential. 
// Contact your metastore administrator to grant you the privilege to this credential.
// abfss://dev-catalog@starsgdtmstrdougslldevuc.dfs.core.windows.net
resource "databricks_external_location" "dev_location" {
  name = "dev-catalog-external-location"
  url = format("abfss://%s@%s.dfs.core.windows.net/",
  azurerm_storage_container.dev_catalog.name, var.storage_unity)
  credential_name = databricks_storage_credential.external_mi.id
  # owner           = "account_unity_admin"
  comment    = "External location used by dev catalog as root storage"
  depends_on = [databricks_storage_credential.external_mi]
}

// Create dev environment catalog
resource "databricks_catalog" "dev" {
  metastore_id = var.metastore_id
  name         = "dev_catalog"
  comment      = "this catalog is for dev env"
  # owner        = "account_unity_admin"
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
  # grant {
  #   principal  = "data_scientist"
  #   privileges = ["USE_CATALOG"]
  # }
  # grant {
  #   principal  = "data_analyst"
  #   privileges = ["USE_CATALOG"]
  # }
}

// Create schema for bronze datalake layer in dev env.
resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.dev.id
  name         = "bronze"
  # owner        = "account_unity_admin"
  comment = "this database is for bronze layer tables/views"
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
  # owner        = "account_unity_admin"
  comment = "this database is for silver layer tables/views"
}

// Grants on silver schema
resource "databricks_grants" "silver" {
  schema = databricks_schema.silver.id
  grant {
    principal  = "data_engineer"
    privileges = ["USE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "EXECUTE", "MODIFY", "SELECT"]
  }
  # grant {
  #   principal  = "data_scientist"
  #   privileges = ["USE_SCHEMA", "SELECT"]
  # }
}

// Create schema for gold datalake layer in dev env.
resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.dev.id
  name         = "gold"
  # owner        = "account_unity_admin"
  comment = "this database is for gold layer tables/views"
}

// Grants on gold schema
resource "databricks_grants" "gold" {
  schema = databricks_schema.gold.id
  grant {
    principal  = "data_engineer"
    privileges = ["USE_SCHEMA", "CREATE_FUNCTION", "CREATE_TABLE", "EXECUTE", "MODIFY", "SELECT"]
  }
  # grant {
  #   principal  = "data_scientist"
  #   privileges = ["USE_SCHEMA", "SELECT"]
  # }
  # grant {
  #   principal  = "data_analyst"
  #   privileges = ["USE_SCHEMA", "SELECT"]
  # }
}
