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
      version = "=4.35.0"
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

  // ##############################################################################################################################
  // ### Sinequa Org parameters
  // ##############################################################################################################################
  org_name                 = "sinequa"
  indexer_capacity         = 3 // Max Number of VMSS Instances Allowed for Indexer
  indexer_vmss_size        = "Standard_B2s"
  st_primary_name         = substr(join("",["stprim",replace(md5(local.resource_group_name),"-","")]),0,24) // Unique Name Across Azure
  st_secondary_name       = substr(join("",["stsec",replace(md5(local.resource_group_name),"-","")]),0,24) // Unique Name Across Azure
  kv_name                 = substr(join("-",["kv",replace(md5(local.resource_group_name),"-","")]),0,24)
  queue_cluster           = "QueueCluster1(@_CloudAlias_node1,@_CloudAlias_node2,@_CloudAlias_node3)" //For Creating a Queuecluster during Cloud Init

  // ##############################################################################################################################
  // ### DEV GRID
  // ##############################################################################################################################
  dev_grid_name               = "dev"

  //    - Primary Nodes Section
  dev_node1_osname            = "vm-dev-node1" //Windows Computer Name
  dev_node1_name              = local.dev_node1_osname //Name in Sinequa Grid
  dev_node2_osname            = "vm-dev-node2" //Windows Computer Name
  dev_node2_name              = local.dev_node2_osname //Name in Sinequa Grid
  dev_node3_osname            = "vm-dev-node3" //Windows Computer Name
  dev_node3_name              = local.dev_node3_osname //Name in Sinequa Grid
  dev_primary_nodes           = "1=srpc://${local.dev_node1_osname}:10301;2=srpc://${local.dev_node2_osname}:10301;3=srpc://${local.dev_node3_osname}:10301" // sRPC Connection String
  dev_primary_node_vm_size    = "Standard_B2s"
  
  //    - Indexer vmss
  dev_os_indexer_name         = "vmss-dev-indexer" //Windows Computer Name

  dev_data_storage_url        = "https://${local.st_primary_name}.blob.core.${local.api_domain}/${local.org_name}/grids/${local.dev_grid_name}/" 
  
  dev_node_aliases            = {
    "node1" = local.dev_node1_name
    "node2" = local.dev_node2_name
    "node3" = local.dev_node3_name
  } 

  dev_image_id                = var.dev_image_id


  // ##############################################################################################################################
  // ### PROD GRID
  // ##############################################################################################################################
  prd_grid_name               = "prd"

  //    - Primary Nodes Section
  prd_node1_osname            = "vm-prd-node1" //Windows Computer Name
  prd_node1_name              = local.prd_node1_osname //Name in Sinequa Grid
  prd_node2_osname            = "vm-prd-node2" //Windows Computer Name
  prd_node2_name              = local.prd_node2_osname //Name in Sinequa Grid
  prd_node3_osname            = "vm-prd-node3" //Windows Computer Name
  prd_node3_name              = local.prd_node3_osname //Name in Sinequa Grid
  prd_primary_nodes           = "1=srpc://${local.prd_node1_osname}:10301;2=srpc://${local.prd_node2_osname}:10301;3=srpc://${local.prd_node3_osname}:10301" // sRPC Connection String
  prd_primary_node_vm_size    = "Standard_B2s"
  
  //    - Indexer vmss
  prd_os_indexer_name         = "vmss-prd-indexer" //Windows Computer Name

  prd_data_storage_url        = "https://${local.st_primary_name}.blob.core.${local.api_domain}/${local.org_name}/grids/${local.prd_grid_name}/" 
 
  prd_node_aliases            = {
    "node1" = local.prd_node1_name
    "node2" = local.prd_node2_name
    "node3" = local.prd_node3_name
  } 

  
  prd_image_id                = var.prd_image_id

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
  st_primary_name       = local.st_primary_name
  st_secondary_name     = local.st_secondary_name 
  license               = local.license
  admin_password        = local.os_admin_password
  org_name              = local.org_name
  default_admin_password = local.sinequa_default_admin_password
  blob_sinequa_keyvault  = local.kv_name
  api_domain            = local.api_domain

  tags = merge({
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg]
}


module "dev_grid_var" {
  source                                = "../../modules/services/blob_grid_var"
  storage_account_name                  = local.st_primary_name
  org_name                              = local.org_name
  grid_name                             = local.dev_grid_name
  blob_sinequa_primary_nodes            = local.dev_primary_nodes 
  blob_sinequa_beta                     = true 
  blob_sinequa_keyvault                 = local.kv_name
  blob_sinequa_queuecluster             = local.queue_cluster
  blob_sinequa_node_aliases             = local.dev_node_aliases

  depends_on = [module.kv_st_services]
}

module "prd_grid_var" {
  source                                = "../../modules/services/blob_grid_var"
  storage_account_name                  = local.st_primary_name
  org_name                              = local.org_name
  grid_name                             = local.prd_grid_name
  blob_sinequa_primary_nodes            = local.prd_primary_nodes 
  blob_sinequa_beta                     = true 
  blob_sinequa_keyvault                 = local.kv_name
  blob_sinequa_queuecluster             = local.queue_cluster
  blob_sinequa_node_aliases             = local.prd_node_aliases

  depends_on = [module.kv_st_services]
}

// ##############################################################################################################################
// ### DEV RESOURCES
// ##############################################################################################################################

// Create Primary Node1
module "vm-dev-primary-node1" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.dev_node1_osname
  computer_name         = local.dev_node1_osname
  vm_size               = local.dev_primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.dev_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  linked_to_application_gateway = false
  network_security_group_id = module.network.nsg_app.id
  //By default a data disk of size 100 GB is created 
  //To create more date disk with different size set - data_disks = [100, 200]  
  pip                   = true

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.dev_data_storage_url
    "sinequa-primary-node-id"             = "1"
    "sinequa-node"                        = local.dev_node1_name
    "sinequa-kestrel-webapp"              = "webApp1"
    "sinequa-webapp-fw-port"              = 80
    "sinequa-engine"                      = "engine1"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}

// Create Primary Node2
module "vm-dev-primary-node2" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.dev_node2_osname
  computer_name         = local.dev_node2_osname
  vm_size               = local.dev_primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.dev_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  network_security_group_id = module.network.nsg_app.id
  //By default a data disk of size 100 GB is created 
  //To create more date disk with different size set - data_disks = [100, 200]  
  pip                   = false

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.dev_data_storage_url
    "sinequa-primary-node-id"             = "2"
    "sinequa-node"                        = local.dev_node2_name
    "sinequa-kestrel-webapp"              = "webApp2"
    "sinequa-webapp-fw-port"              = 80
    "sinequa-engine"                      = "engine2"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}

// Create Primary Node3
module "vm-dev-primary-node3" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.dev_node3_osname
  computer_name         = local.dev_node3_osname
  vm_size               = local.dev_primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.dev_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  network_security_group_id = module.network.nsg_app.id
  //By default a data disk of size 100 GB is created 
  //To create more date disk with different size set - data_disks = [100, 200]  
  pip                   = false

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.dev_data_storage_url
    "sinequa-primary-node-id"             = "3"
    "sinequa-node"                        = local.dev_node3_name
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}

// Create Indexer Scale Set
module "vmss-dev-indexer1" {
  source                = "../../modules/vmss"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vmss_name             = local.dev_os_indexer_name
  computer_name_prefix  = "indexer"
  vmss_size             = local.indexer_vmss_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.dev_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  user_identity_principal_id = module.kv_st_services.id.principal_id
  network_security_group_id = module.network.nsg_app.id
  vmss_capacity         = local.indexer_capacity

  tags = merge({
    "sinequa-data-storage-url"            = local.dev_data_storage_url
    "sinequa-node"                        = local.dev_os_indexer_name
    "sinequa-indexer"                     = "elastic-indexer"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services,module.vm-dev-primary-node1,module.vm-dev-primary-node2,module.vm-dev-primary-node3]
}


// ##############################################################################################################################
// ### PRD RESOURCES
// ##############################################################################################################################

// Create Primary Node1
module "vm-prd-primary-node1" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.prd_node1_osname
  computer_name         = local.prd_node1_osname
  vm_size               = local.prd_primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.prd_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  linked_to_application_gateway = false
  network_security_group_id = module.network.nsg_app.id
  //By default a data disk of size 100 GB is created 
  //To create more date disk with different size set - data_disks = [100, 200]  
  pip                   = true

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.prd_data_storage_url
    "sinequa-primary-node-id"             = "1"
    "sinequa-node"                        = local.prd_node1_name
    "sinequa-kestrel-webapp"              = "webApp1"
    "sinequa-webapp-fw-port"              = 80
    "sinequa-engine"                      = "engine1"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}

// Create Primary Node2
module "vm-prd-primary-node2" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.prd_node2_osname
  computer_name         = local.prd_node2_osname
  vm_size               = local.prd_primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.prd_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  network_security_group_id = module.network.nsg_app.id
  //By default a data disk of size 100 GB is created 
  //To create more date disk with different size set - data_disks = [100, 200]  
  pip                   = false

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.prd_data_storage_url
    "sinequa-primary-node-id"             = "2"
    "sinequa-node"                        = local.prd_node2_name
    "sinequa-kestrel-webapp"              = "webApp2"
    "sinequa-webapp-fw-port"              = 80
    "sinequa-engine"                      = "engine2"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}

// Create Primary Node3
module "vm-prd-primary-node3" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.prd_node3_osname
  computer_name         = local.prd_node3_osname
  vm_size               = local.prd_primary_node_vm_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.prd_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  network_security_group_id = module.network.nsg_app.id
  //By default a data disk of size 100 GB is created 
  //To create more date disk with different size set - data_disks = [100, 200]  
  pip                   = false

  tags = merge({
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.prd_data_storage_url
    "sinequa-primary-node-id"             = "3"
    "sinequa-node"                        = local.prd_node3_name
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}

// Create Indexer Scale Set
module "vmss-prd-indexer1" {
  source                = "../../modules/vmss"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vmss_name             = local.prd_os_indexer_name
  computer_name_prefix  = "indexer"
  vmss_size             = local.indexer_vmss_size
  subnet_id             = module.network.subnet_app.id
  image_id              = local.prd_image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  user_identity_id      = module.kv_st_services.id.id
  user_identity_principal_id = module.kv_st_services.id.principal_id
  network_security_group_id = module.network.nsg_app.id
  vmss_capacity         = local.indexer_capacity

  tags = merge({
    "sinequa-data-storage-url"            = local.prd_data_storage_url
    "sinequa-node"                        = local.prd_os_indexer_name
    "sinequa-indexer"                     = "elastic-indexer"
  },var.additional_tags)

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services,module.vm-prd-primary-node1,module.vm-prd-primary-node2,module.vm-prd-primary-node3]
}


// ##############################################################################################################################
// ### OUTPUTs
// ##############################################################################################################################

output "os_user" {
    value        = local.os_admin_username
}

output "os_password" {
    value        = nonsensitive(local.os_admin_password) // nonsensitive only for testing. This function should be removed.
}

output "sinequa_admin_password" {
    value        = nonsensitive(local.sinequa_default_admin_password) // nonsensitive only for testing. This function should be removed.
}

data "azurerm_public_ip" "dev_public_ip" {
  name = module.vm-dev-primary-node1.pip[0].name
  resource_group_name = azurerm_resource_group.sinequa_rg.name
  depends_on = [ module.vm-dev-primary-node1.pip, module.vm-dev-primary-node1.vm ]
}

data "azurerm_public_ip" "prd_public_ip" {
  name = module.vm-prd-primary-node1.pip[0].name
  resource_group_name = azurerm_resource_group.sinequa_rg.name
  depends_on = [ module.vm-prd-primary-node1.pip, module.vm-prd-primary-node1.vm ]
}


output "sinequa_dev_admin_url" {
  value = "http://${data.azurerm_public_ip.dev_public_ip.ip_address}/admin"
}

output "sinequa_prd_admin_url" {
  value = "http://${data.azurerm_public_ip.prd_public_ip.ip_address}/admin"
}