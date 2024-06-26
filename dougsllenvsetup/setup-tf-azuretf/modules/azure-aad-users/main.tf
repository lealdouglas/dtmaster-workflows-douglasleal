data "azurerm_client_config" "current" {
}

#Criando um grupo de Data Engineers
resource "azuread_group" "data_engineers" {
  display_name     = "data_engineer"
  description      = "Group for Data Engineers"
  security_enabled = true
}

# #Criando um grupo de Data Engineers
# resource "azuread_group" "account_unity_admin" {
#   display_name     = "account_unity_admin"
#   description      = "Group for Admin Unity Account"
#   security_enabled = true
# }

# Criando os usuários
resource "azuread_user" "user1" {
  display_name        = "Minato"
  user_principal_name = "minato@douglasslealoutlook.onmicrosoft.com"
  password            = "Password1234!"
  mail_nickname       = "Minato"
  given_name          = "minato"
  job_title           = "data_engineer"
  department          = "Engineering"
  account_enabled     = true
}

resource "azuread_application" "this" {
  display_name = "spn${var.suffix_concat}"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]
  account_enabled              = true
}

resource "time_rotating" "month" {
  rotation_days = 30
}

resource "azuread_service_principal_password" "this" {
  service_principal_id = azuread_service_principal.this.object_id
  rotate_when_changed  = { rotation = time_rotating.month.id }
}

# Adicionando os usuários ao grupo de Data Engineers
resource "azuread_group_member" "user1_member" {
  group_object_id  = azuread_group.data_engineers.id
  member_object_id = azuread_user.user1.id
}

resource "azuread_group_member" "user4_member" {
  group_object_id  = azuread_group.data_engineers.id
  member_object_id = azuread_service_principal.this.object_id
}

