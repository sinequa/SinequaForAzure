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
  name                     = var.st_hot_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  tags                      = var.tags

  depends_on = [azurerm_user_assigned_identity.identity]
}

resource "azurerm_storage_account" "sinequa_st_premium" {
  name                     = var.st_premium_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Premium"
  account_kind             = "BlockBlobStorage"
  account_replication_type = "LRS"
  access_tier              = "Cool"
  tags                      = var.tags

  depends_on = [azurerm_user_assigned_identity.identity]
}

resource "azurerm_storage_container" "sinequa_st_hot_container" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.sinequa_st_hot.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "sinequa_st_premium_container" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.sinequa_st_premium.name
  container_access_type = "private"
}


resource "azurerm_storage_blob" "st-org-root-secondary" {
  name                   = join("",[var.data_storage_root, "var/st-org-root-secondary"])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = "https://${var.st_hot_name}.blob.core.windows.net/${var.container_name}"
}

resource "azurerm_storage_blob" "sinequa_primary_nodes" {
  name                   = join("",[var.data_storage_root, "var/sinequa-primary-nodes"])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_primary_nodes
}

resource "azurerm_storage_blob" "sinequa_authentication_enabled" {
  count                  = var.blob_sinequa_authentication_enabled?1:0
  name                   = join("",[var.data_storage_root, "var/sinequa-authentication-enabled"])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = "true"
}


resource "azurerm_storage_blob" "sinequa_beta" {
  name                   = join("",[var.data_storage_root, "var/sinequa-beta"])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_beta
}

resource "azurerm_storage_blob" "sinequa-keyvault" {
  name                   = join("",[var.data_storage_root, "var/sinequa-keyvault"])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_keyvault
}

resource "azurerm_storage_blob" "sinequa-queuecluster" {
  count                  = var.blob_sinequa_queuecluster != ""?1:0
  name                   = join("",[var.data_storage_root, "var/sinequa-queue-cluster"])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_queuecluster
}

resource "azurerm_storage_blob" "sinequa-version" {
  count                   = var.blob_sinequa_version != ""?1:0
  name                   = join("",[var.data_storage_root, "var/sinequa-version"])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_version
}

resource "azurerm_storage_blob" "sinequa-node-aliases" {
  for_each               = var.blob_sinequa_node_aliases
  name                   = join("",[var.data_storage_root, "aliases/node/", each.key])
  storage_account_name   = azurerm_storage_account.sinequa_st_premium.name
  storage_container_name = azurerm_storage_container.sinequa_st_premium_container.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = each.value
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





