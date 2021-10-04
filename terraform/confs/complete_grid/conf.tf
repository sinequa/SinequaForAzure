terraform {
  backend "azurerm" {
    resource_group_name   = "tfstate"
    storage_account_name  = "sinequatfstate"
    container_name        = "tstate"
    key                   = "dev.complete_grid.terraform.tfstate"
  }
}

provider "azurerm" {
  partner_id = "947f5924-5e20-4f0a-96eb-808371995ac8" // Sinequa Tracking ID
  subscription_id = var.sub_www_id
  tenant_id       = var.tenant_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }  
}

data "azurerm_client_config" "current" {}

locals {
  region                  = "francecentral"
  resource_group_name     = var.resource_group_name
  prefix                  = "sq"
  sinequa_grid            = "test"
  os_admin_username       = "sinequa"
  os_admin_password       = element(concat(random_password.passwd.*.result, [""]), 0)
  license                 = fileexists("../sinequa.license.txt")?file("../sinequa.license.txt"):""
  node1_name              = "node1"  
  node1_osname            = "vm-node1"  
  node2_name              = "node2"  
  node2_osname            = "vm-node2"    
  node3_name              = "node3"  
  node3_osname            = "vm-node3"  
  primary_nodes           = join("",["1=srpc://", local.node1_osname ,":10301",";2=srpc://", local.node2_osname ,":10301",";3=srpc://", local.node3_osname ,":10301"])
  st_name                 = substr(join("",["st",replace(md5(local.resource_group_name),"-","")]),0,24)
  kv_name                 = substr(join("-",["kv",local.prefix,replace(md5(local.resource_group_name),"-","")]),0,24)
  queue_cluster           = join("",["QueueCluster1('",local.node1_name,"')"])
  st_container_name       = "sinequa"
  data_storage_url        = join("",["https://",local.st_name,".blob.core.windows.net/",local.st_container_name])
  image_id                = "/subscriptions/8c2243fe-2eba-45da-bf61-0ceb475dcde8/resourceGroups/rg-rnd-product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-${var.repo}/versions/${replace(var.version_number,"/^[0-9]+./","")}"
  
  ssl_certificate = {
    "name"                  = "SinequaSSL"
    "data"                  = "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"
    "password"              = "sinequa"
    "key_vault_secret_id"   = null
  }  
}


resource "random_password" "passwd" {
  length      = 24
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false

  keepers = {
    domain_name_label = local.prefix
  }
}


// Create the resource group
resource "azurerm_resource_group" "sinequa_rg" {
  name = local.resource_group_name
  location = local.region

  tags = {
    "sinequa-grid" = local.prefix
  }
}


// Create Network (vnet + subnet + nsg)
module "network" {
  source                = "../../modules/network"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vnet_name             = "vnet-${local.prefix}"
  nsg_app_name          = "nsg-${local.prefix}-app"
  nsg_front_name        = "nsg-${local.prefix}-front"

  tags = {
    "sinequa-grid" = local.prefix
  }

}


// Create Frontend (application gateway)
module "frontend" {
  source                = "../../modules/frontend"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  availability_set_name = "as-${local.prefix}"
  application_gateway_name = "ag-${local.prefix}"
  subnet_id             = module.network.subnet_front.id
  certificate           = local.ssl_certificate

  tags = {
    "sinequa-grid" = local.prefix
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.network]
}

// Create Key Vault & Storage Account
module "kv_st_services" {
  source                = "../../modules/services"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  kv_name               = local.kv_name
  st_name               = local.st_name
  license               = local.license
  container_name        = local.st_container_name
  admin_password        = local.os_admin_password

  blob_sinequa_primary_nodes = local.primary_nodes 
  blob_sinequa_beta          = true
  blob_sinequa_keyvault      = local.kv_name
  blob_sinequa_queuecluster  = local.queue_cluster

  depends_on = [azurerm_resource_group.sinequa_rg]
}

// Create Primary Node1
module "vm-primary-node1" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = "vm-${local.prefix}-${local.node1_name}"
  computer_name         = local.node1_osname
  vm_size               = "Standard_B2s"
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  availability_set_id   = module.frontend.as.id
  linked_to_application_gateway = true
  backend_address_pool_id = module.frontend.ag.backend_address_pool[0].id
  network_security_group_id = module.network.nsg_app.id
  pip                   = true

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "1"
    "sinequa-node"                        = local.node1_name
    "sinequa-webapp"                      = "webApp1"
    "sinequa-engine"                      = "engine1"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services, module.frontend]
}

// Create Primary Node2
module "vm-primary-node2" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = "vm-${local.prefix}-${local.node2_name}"
  computer_name         = local.node2_osname
  vm_size               = "Standard_B2s"
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  availability_set_id   = module.frontend.as.id
  linked_to_application_gateway = true
  backend_address_pool_id = module.frontend.ag.backend_address_pool[0].id
  network_security_group_id = module.network.nsg_app.id
  pip                   = true

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "2"
    "sinequa-node"                        = local.node2_name
    "sinequa-webapp"                      = "webApp2"
    "sinequa-engine"                      = "engine2"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services, module.frontend]
}

// Create Primary Node3
module "vm-primary-node3" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = "vm-${local.prefix}-${local.node3_name}"
  computer_name         = local.node3_osname
  vm_size               = "Standard_B2s"
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  availability_set_id   = module.frontend.as.id
  linked_to_application_gateway = true
  backend_address_pool_id = module.frontend.ag.backend_address_pool[0].id
  network_security_group_id = module.network.nsg_app.id
  pip                   = true

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "3"
    "sinequa-node"                        = local.node3_name
    "sinequa-indexer"                     = "indexer1"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services, module.frontend]
}

// Create Indexer Scale Set
module "vmss-indexer1" {
  source                = "../../modules/vmss"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vmss_name             = "vmss-${local.prefix}-indexer"
  computer_name_prefix  = "indexer"
  vmss_size             = "Standard_B2s"
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  network_security_group_id = module.network.nsg_app.id

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-node"                        = "indexer1"
    "sinequa-indexer"                     = "indexer-dynamic"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}

output "sinequa_admin_url" {
  value = "https://${module.frontend.pip.ip_address}/admin"
}