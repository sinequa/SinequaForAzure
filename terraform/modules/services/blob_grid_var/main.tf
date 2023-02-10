resource "azurerm_storage_blob" "sinequa_primary_nodes" {
  name                   = "grids/${var.grid_name}/var/sinequa-primary-nodes"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_primary_nodes
}

resource "azurerm_storage_blob" "sinequa_authentication_enabled" {
  count                  = var.blob_sinequa_authentication_enabled?1:0
  name                   = "grids/${var.grid_name}/var/sinequa-authentication-enabled"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = "true"
}


resource "azurerm_storage_blob" "sinequa_beta" {
  name                   = "grids/${var.grid_name}/var/sinequa-beta"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_beta
}

resource "azurerm_storage_blob" "sinequa-keyvault" {
  name                   = "grids/${var.grid_name}/var/sinequa-keyvault"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_keyvault
}

resource "azurerm_storage_blob" "sinequa-queuecluster" {
  count                  = var.blob_sinequa_queuecluster != ""?1:0
  name                   = "grids/${var.grid_name}/var/sinequa-queue-cluster"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_queuecluster
}

resource "azurerm_storage_blob" "sinequa-version" {
  count                   = var.blob_sinequa_version != ""?1:0
  name                   = "grids/${var.grid_name}/var/sinequa-version"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.blob_sinequa_version
}

resource "azurerm_storage_blob" "sinequa-node-aliases" {
  for_each               = var.blob_sinequa_node_aliases
  name                   = "grids/${var.grid_name}/aliases/node/${each.key}"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = each.value
}

resource "azurerm_storage_blob" "sinequa-nodelist-aliases" {
  for_each               = var.blob_sinequa_nodelist_aliases
  name                   = "grids/${var.grid_name}/aliases/nodelist/${each.key}"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = each.value
}

resource "azurerm_storage_blob" "sinequa-engine-aliases" {
  for_each               = var.blob_sinequa_engine_aliases
  name                   = "grids/${var.grid_name}/aliases/engine/${each.key}"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = each.value
}

resource "azurerm_storage_blob" "sinequa-enginelist-aliases" {
  for_each               = var.blob_sinequa_enginelist_aliases
  name                   = "grids/${var.grid_name}/aliases/enginelist/${each.key}"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = each.value
}

resource "azurerm_storage_blob" "sinequa-indexer-aliases" {
  for_each               = var.blob_sinequa_indexer_aliases
  name                   = "grids/${var.grid_name}/aliases/indexer/${each.key}"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = each.value
}

resource "azurerm_storage_blob" "sinequa-indexerlist-aliases" {
  for_each               = var.blob_sinequa_indexerlist_aliases
  name                   = "grids/${var.grid_name}/aliases/indexerlist/${each.key}"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.org_name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = each.value
}