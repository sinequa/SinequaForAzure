data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "identity" {
  resource_group_name = var.resource_group_name
  location            = var.location

  name = "id-sq"
}
resource "azurerm_key_vault" "sinequa_kv" {
  name                        = var.kv_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = false
  enable_rbac_authorization   = true
  sku_name                    = "standard"
  tags                        = var.tags

  depends_on = [azurerm_user_assigned_identity.identity]
}


resource "azurerm_role_assignment" "sinequa_kv_role_for_me" {
  scope                = azurerm_key_vault.sinequa_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_key_vault.sinequa_kv]
}

resource "azurerm_role_assignment" "sinequa_kv_role_for_id" {
  scope                = azurerm_key_vault.sinequa_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id

  depends_on = [azurerm_user_assigned_identity.identity, azurerm_key_vault.sinequa_kv]
}


resource "azurerm_key_vault_secret" "sinequa_kv_secret_sinequa_license" {
  name         = "sinequa-license"
  value        = var.license
  key_vault_id = azurerm_key_vault.sinequa_kv.id

  depends_on = [azurerm_role_assignment.sinequa_kv_role_for_me]
}

resource "azurerm_key_vault_secret" "sinequa_kv_secret_password" {
  name         = "os-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.sinequa_kv.id

  depends_on = [azurerm_role_assignment.sinequa_kv_role_for_me]
}

resource "azurerm_key_vault_secret" "sinequa_kv_default_admin_password" {
  name         = "sinequa-default-admin-password"
  value        = var.default_admin_password
  key_vault_id = azurerm_key_vault.sinequa_kv.id

  depends_on = [azurerm_role_assignment.sinequa_kv_role_for_me]
}

resource "azurerm_key_vault_secret" "sinequa_authentication_secret" {
  count                  = var.blob_sinequa_authentication_enabled?1:0
  name                   = "sinequa-authentication-secret"
  value                  = var.blob_sinequa_authentication_secret
  key_vault_id           = azurerm_key_vault.sinequa_kv.id

  depends_on = [azurerm_role_assignment.sinequa_kv_role_for_me]
}



resource "azurerm_storage_account" "sinequa_st_hot" {
  name                     = var.st_secondary_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  tags                      = var.tags

  depends_on = [azurerm_user_assigned_identity.identity]
}

resource "azurerm_storage_account" "sinequa_st_premium" {
  name                     = var.st_primary_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Premium"
  account_kind             = "BlockBlobStorage"
  account_replication_type = "LRS"
  tags                      = var.tags

  depends_on = [azurerm_user_assigned_identity.identity]
}

resource "azurerm_storage_container" "sinequa_st_hot_container" {
  name                  = var.org_name
  storage_account_name  = azurerm_storage_account.sinequa_st_hot.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.sinequa_st_hot]
}

resource "azurerm_storage_container" "sinequa_st_premium_container" {
  name                  = var.org_name
  storage_account_name  = azurerm_storage_account.sinequa_st_premium.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.sinequa_st_premium]
}


resource "azurerm_storage_blob" "sinequa-secondary" {
  name                   = "var/sinequa-secondary"
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = "https://${var.st_secondary_name}.blob.core.${var.api_domain}/${var.org_name}"

  depends_on = [azurerm_storage_container.sinequa_st_premium_container]
}

module "grid_var" {
  count                                 = var.grid_name!=""?1:0
  source                                = "./blob_grid_var"
  storage_account_name                  = azurerm_storage_account.sinequa_st_premium.name
  org_name                              = var.org_name
  grid_name                             = var.grid_name
  blob_sinequa_primary_nodes            = var.blob_sinequa_primary_nodes
  blob_sinequa_beta                     = var.blob_sinequa_beta 
  blob_sinequa_keyvault                 = var.blob_sinequa_keyvault
  blob_sinequa_queuecluster             = var.blob_sinequa_queuecluster
  blob_sinequa_authentication_enabled   = var.blob_sinequa_authentication_enabled
  blob_sinequa_node_aliases             = var.blob_sinequa_node_aliases
  blob_sinequa_nodelist_aliases         = var.blob_sinequa_nodelist_aliases
  blob_sinequa_engine_aliases             = var.blob_sinequa_engine_aliases
  blob_sinequa_enginelist_aliases         = var.blob_sinequa_enginelist_aliases
  blob_sinequa_indexer_aliases             = var.blob_sinequa_indexer_aliases
  blob_sinequa_indexerlist_aliases         = var.blob_sinequa_indexerlist_aliases
  
  blob_sinequa_version                  = var.blob_sinequa_version

  depends_on = [azurerm_storage_account.sinequa_st_premium,azurerm_storage_container.sinequa_st_premium_container]
}

resource "azurerm_role_assignment" "sinequa_st_hot_role_id" {
  scope                 = azurerm_storage_account.sinequa_st_hot.id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = azurerm_user_assigned_identity.identity.principal_id

  depends_on = [azurerm_user_assigned_identity.identity, azurerm_storage_account.sinequa_st_hot]
}
resource "azurerm_role_assignment" "sinequa_st_premium_role_id" {
  scope                 = azurerm_storage_account.sinequa_st_premium.id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = azurerm_user_assigned_identity.identity.principal_id

  depends_on = [azurerm_user_assigned_identity.identity, azurerm_storage_account.sinequa_st_premium]
}





