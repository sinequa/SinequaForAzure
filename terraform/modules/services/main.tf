data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "sinequa_kv" {
  name                        = var.kv_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = false
  enable_rbac_authorization   = true
  sku_name                    = "standard"
  tags                        = var.tags
}

resource "azurerm_role_assignment" "sinequa_kv_role_for_me" {
  scope                = azurerm_key_vault.sinequa_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "sinequa_kv_secret_user" {
  name         = "os-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.sinequa_kv.id

  depends_on = [azurerm_role_assignment.sinequa_kv_role_for_me]
}

resource "azurerm_key_vault_secret" "sinequa_kv_secret_password" {
  name         = "os-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.sinequa_kv.id
  
  depends_on = [azurerm_role_assignment.sinequa_kv_role_for_me]
}

resource "azurerm_key_vault_secret" "sinequa_kv_secret_sinequa_license" {
  name         = "sinequa-license"
  value        = var.license
  key_vault_id = azurerm_key_vault.sinequa_kv.id

  depends_on = [azurerm_role_assignment.sinequa_kv_role_for_me]
}

resource "azurerm_storage_account" "sinequa_st" {
  name                     = var.st_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                      = var.tags
}

resource "azurerm_storage_container" "sinequa_st_container" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.sinequa_st.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "sinequa_primary_nodes" {
  name                   = "var/sinequa-primary-nodes"
  storage_account_name   = azurerm_storage_account.sinequa_st.name
  storage_container_name = azurerm_storage_container.sinequa_st_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_primary_nodes
}

resource "azurerm_storage_blob" "sinequa_beta" {
  name                   = "var/sinequa-beta"
  storage_account_name   = azurerm_storage_account.sinequa_st.name
  storage_container_name = azurerm_storage_container.sinequa_st_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_beta
}

resource "azurerm_storage_blob" "sinequa-keyvault" {
  name                   = "var/sinequa-keyvault"
  storage_account_name   = azurerm_storage_account.sinequa_st.name
  storage_container_name = azurerm_storage_container.sinequa_st_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_keyvault
}

resource "azurerm_storage_blob" "sinequa_queuecluster" {
  count                  = var.blob_sinequa_queuecluster != ""?1:0
  name                   = "var/sinequa-queuecluster"
  storage_account_name   = azurerm_storage_account.sinequa_st.name
  storage_container_name = azurerm_storage_container.sinequa_st_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_queuecluster
}
