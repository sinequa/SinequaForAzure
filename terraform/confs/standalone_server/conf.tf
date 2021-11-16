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
  region                  = "francecentral"
  resource_group_name     = var.resource_group_name
  os_admin_username       = "sinequa" // Windows Login Name
  os_admin_password       = element(concat(random_password.passwd.*.result, [""]), 0) // Windows Login Password

  sinequa_default_admin_password = element(concat(random_password.sq_passwd.*.result, [""]), 0) // Sinequa Admin user password
  license                 = fileexists("../sinequa.license.txt")?file("../sinequa.license.txt"):"" //Sinequa License
  
  //Primary Nodes Section
  node1_osname            = "vm-node1" //Windows Computer Name
  node1_name              = local.node1_osname //Name in Sinequa Grid
  primary_nodes           = "1=srpc://${local.node1_osname}:10301" // sRPC Connection String
  primary_node_vm_size    = "Standard_B2s"
  data_disk_size        = 100 // Size of Datadisk (for data such as Indexes)

  st_name                 = substr(join("",["st",replace(md5(local.resource_group_name),"-","")]),0,24) // Unique Name Across Azure
  st_container_name       = "sinequa"

  data_storage_root       = "grids/${var.resource_group_name}/"
  data_storage_url        = "https://${local.st_name}.blob.core.windows.net/${local.st_container_name}/${local.data_storage_root}"
  kv_name                 = substr(join("-",["kv",replace(md5(local.resource_group_name),"-","")]),0,24)
  queue_cluster           = "QueueCluster1(${local.node1_name})" //For Creating a Queuecluster during Cloud Init
  image_id                = var.image_id

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
  location = local.region

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
  require_front_subnet  = false
  allow_http_on_app_nsg = true

  tags = merge({
  },var.additional_tags)

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
  data_storage_root     = local.data_storage_root
  default_admin_password = local.sinequa_default_admin_password

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
  storage_account_id    = module.kv_st_services.st.id
  network_security_group_id = module.network.nsg_app.id
  data_disk_size        = local.data_disk_size
  pip                   = true

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "1"
    "sinequa-node"                        = local.node1_name
    "sinequa-webapp"                      = "webApp1"
    "sinequa-engine"                      = "engine1"
    "sinequa-indexer"                     = "indexer1"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
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

data "azurerm_public_ip" "public_ip" {
  name = module.vm-primary-node1.pip[0].name
  resource_group_name = azurerm_resource_group.sinequa_rg.name
  depends_on = [ module.vm-primary-node1.pip, module.vm-primary-node1.vm ]
}

output "sinequa_admin_url" {
  value = "http://${data.azurerm_public_ip.public_ip.ip_address}/admin"
}