terraform {
  /*
  // Not Needed for Testing
  // Usefull for Production in order to persist Terraform State in Azure
  backend "azurerm" {
    resource_group_name   = "<resource group name for storing the tfstate>"
    storage_account_name  = "<storage account name for storing the tfstate>"
    container_name        = "<container name for storing the tfstate>"
    key                   = "<key name>" // e.g. dev.my_deployment.terraform.tfstate
  } 
  */
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.68.0"
    }
  }
}

provider "azurerm" {
  partner_id = "947f5924-5e20-4f0a-96eb-808371995ac8" // Sinequa Tracking ID
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }  
}

data "azurerm_client_config" "current" {}

locals {
  resource_group_name     = var.resource_group_name
  os_admin_username       = "sinequa" // Windows Login Name
  os_admin_password       = element(concat(random_password.passwd.*.result, [""]), 0) // Windows Login Password

  sinequa_default_admin_password = element(concat(random_password.sq_passwd.*.result, [""]), 0) // Sinequa Admin user password
  license                 = fileexists("../sinequa.license.txt")?file("../sinequa.license.txt"):"" //Sinequa License
  api_domain              = var.azure_environment == "AzureUSGovernment"?"usgovcloudapi.net":(var.azure_environment == "AzureGermanCloud"?"microsoftazure.de":(var.azure_environment == "AzureChinaCloud"?"vault.azure.cn":"windows.net"))
  
  //Sinequa Org & Grid  
  org_name                 = "sinequa"
  grid_name                = var.resource_group_name

  //Primary Nodes Section
  node1_osname            = "vm-node1" //Windows Computer Name
  node1_name              = local.node1_osname //Name in Sinequa Grid
  node2_osname            = "vm-node2" //Windows Computer Name
  node2_name              = local.node2_osname //Name in Sinequa Grid
  node3_osname            = "vm-node3" //Windows Computer Name
  node3_name              = local.node3_osname //Name in Sinequa Grid
  primary_nodes           = "1=srpc://${local.node1_osname}:10301;2=srpc://${local.node2_osname}:10301;3=srpc://${local.node3_osname}:10301" // sRPC Connection String
  primary_node_vm_size    = "Standard_B2s"
  data_disk_size          = 100 // Size of DataDisk (for data such as Indexes)

  // Indexer vmss
  os_indexer_name         = "vmss-indexer" //Windows Computer Name
  indexer_capacity         = 3 // Max Number of VMSS Instances Allowed for Indexer
  indexer_vmss_size       = "Standard_B2s"

  st_primary_name         = substr(join("",["stprim",replace(md5(local.resource_group_name),"-","")]),0,24) // Unique Name Across Azure
  st_secondary_name       = substr(join("",["stsec",replace(md5(local.resource_group_name),"-","")]),0,24) // Unique Name Across Azure
  st_container_name       = "sinequa"

  data_storage_url        = "https://${local.st_primary_name}.blob.core.${local.api_domain}/${local.org_name}/grids/${local.grid_name}/"
  kv_name                 = substr(join("-",["kv",replace(md5(local.resource_group_name),"-","")]),0,24)
  queue_cluster           = "QueueCluster1(${local.node1_name},${local.node2_name},${local.node3_name})" //For Creating a Queuecluster during Cloud Init
  
  image_id                = var.image_id

  ssl_certificate = {  // Self Signed SSL Certificate (HTTPS) used for the Application Gateway
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
    domain_name_label = local.resource_group_name
  }
}

resource "random_password" "sq_passwd" {
  length      = 24
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false

  keepers = {
    domain_name_label = local.resource_group_name
  }
}

// Create the resource group
resource "azurerm_resource_group" "sinequa_rg" {
  name = local.resource_group_name
  location = var.location

  tags = merge({
  },var.additional_tags)
}


// Create Network (vnet + subnet + nsg)
module "network" {
  source                = "../../modules/network"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vnet_name             = "vnet"
  nsg_app_name          = "nsg-app"
  nsg_front_name        = "nsg-front"
  require_front_subnet  = true
  allow_http_on_app_nsg = false

  tags = merge({
  },var.additional_tags)

}



// Create Frontend (application gateway)
module "frontend" {
  source                = "../../modules/frontend"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  availability_set_name = "as"
  application_gateway_name = "ag"
  subnet_id             = module.network.subnet_front[0].id
  certificate           = local.ssl_certificate

  tags = merge({
  },var.additional_tags)


  depends_on = [azurerm_resource_group.sinequa_rg, module.network]
}


// Create Key Vault & Storage Account
module "kv_st_services" {
  source                = "../../modules/services"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  kv_name               = local.kv_name
  st_primary_name       = local.st_primary_name
  st_secondary_name     = local.st_secondary_name 
  license               = local.license
  org_name              = local.org_name
  grid_name             = local.grid_name
  admin_password        = local.os_admin_password
  default_admin_password = local.sinequa_default_admin_password
  api_domain            = local.api_domain

  blob_sinequa_primary_nodes = local.primary_nodes 
  blob_sinequa_beta          = true
  blob_sinequa_keyvault      = local.kv_name
  blob_sinequa_queuecluster  = local.queue_cluster

  tags = merge({
  },var.additional_tags)


  depends_on = [azurerm_resource_group.sinequa_rg]
}

// Create Primary Node1
module "vm-primary-node1" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.node1_osname
  computer_name         = local.node1_osname
  vm_size               = local.primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  user_identity_id      = module.kv_st_services.id.id
  availability_set_id   = module.frontend.as.id
  linked_to_application_gateway = true
  backend_address_pool_ids = module.frontend.ag.backend_address_pool[*].id
  network_security_group_id = module.network.nsg_app.id
  data_disk_size        = local.data_disk_size
  pip                   = true

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "1"
    "sinequa-node"                        = local.node1_name
    "sinequa-kestrel-webapp"              = "webApp1"
    "sinequa-webapp-fw-port"              = 80
    "sinequa-engine"                      = "engine1"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services] //, module.frontend
}

// Create Primary Node2
module "vm-primary-node2" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.node2_osname
  computer_name         = local.node2_osname
  vm_size               = local.primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  user_identity_id      = module.kv_st_services.id.id
  availability_set_id   = module.frontend.as.id
  linked_to_application_gateway = true
  backend_address_pool_ids = module.frontend.ag.backend_address_pool[*].id
  network_security_group_id = module.network.nsg_app.id
  data_disk_size        = local.data_disk_size
  pip                   = false

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "2"
    "sinequa-node"                        = local.node2_name
    "sinequa-kestrel-webapp"              = "webApp2"
    "sinequa-webapp-fw-port"              = 80    
    "sinequa-engine"                      = "engine2"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services] //module.frontend
}

// Create Primary Node3
module "vm-primary-node3" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.node3_osname
  computer_name         = local.node3_osname
  vm_size               = local.primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  user_identity_id      = module.kv_st_services.id.id
  availability_set_id   = module.frontend.as.id
  linked_to_application_gateway = false
  backend_address_pool_ids = module.frontend.ag.backend_address_pool[*].id
  network_security_group_id = module.network.nsg_app.id
  data_disk_size        = local.data_disk_size
  pip                   = false

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "3"
    "sinequa-node"                        = local.node3_name
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services] //module.frontend
}

// Create Indexer Scale Set
module "vmss-indexer1" {
  source                = "../../modules/vmss"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vmss_name             = local.os_indexer_name
  computer_name_prefix  = "indexer"
  vmss_size             = local.indexer_vmss_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  user_identity_id      = module.kv_st_services.id.id
  user_identity_principal_id = module.kv_st_services.id.principal_id
  network_security_group_id = module.network.nsg_app.id
  vmss_capacity         = local.indexer_capacity

  tags = merge({
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-node"                        = local.os_indexer_name
    "sinequa-indexer"                     = "elastic-indexer"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services,module.vm-primary-node1,module.vm-primary-node2,module.vm-primary-node3]
}

output "os_user" {
    value        = local.os_admin_username
}

output "os_password" {
    value        = nonsensitive(local.os_admin_password) // nonsensitive only for testing. This function should be removed.
}

output "sinequa_admin_password" {
    value        = nonsensitive(local.sinequa_default_admin_password) // nonsensitive only for testing. This function should be removed.
}

output "sinequa_admin_url" {
  value = "https://${module.frontend.pip.ip_address}/admin"
}