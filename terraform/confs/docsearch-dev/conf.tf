terraform {
  backend "azurerm" {
    resource_group_name = "rg-www-tf"
    storage_account_name  = "satfwwwsnqa"
    container_name  = "terraform"
    key = "tf.docsearch-dev.tfstate"
  }
}

provider "azuread" {}

provider "azurerm" {
  partner_id = "947f5924-5e20-4f0a-96eb-808371995ac8" // Sinequa Tracking ID
  subscription_id = var.sub_www_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }  
}

data "azurerm_client_config" "current" {}

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

// Specify an existing subnet of a virtual network
data "azurerm_key_vault" "kv-snqa" {
  name                 = "kv-snqa-management-key"
  resource_group_name  = "rg-www-security"
}

data "azurerm_key_vault_secret" "sinequa_ad_secret" {
  name         = "azuredomainjoiner"
  key_vault_id = data.azurerm_key_vault.kv-snqa.id

  depends_on = [data.azurerm_key_vault.kv-snqa]
}

locals {
  region                  = "francecentral"
  resource_group_name     = "rg-www-docsearch-dev"
  prefix                  = "doc"
  os_admin_username       = "sinequa"
  os_admin_password       = element(concat(random_password.passwd.*.result, [""]), 0)
  license                 = fileexists("../sinequa.license.txt")?file("../sinequa.license.txt"):""
  node1_name              = "docsearch-dev1"  
  node2_name              = "docsearch-dev2"  
  primary_nodes           = join("",["1=srpc://", local.node1_name ,":10301"])
  st_name                 = substr(join("",["st",replace(md5(local.resource_group_name),"-","")]),0,24)
  kv_name                 = substr(join("-",["kv",local.prefix,replace(md5(local.resource_group_name),"-","")]),0,24)
  st_container_name       = "sinequa"
  data_storage_url        = join("",["https://",local.st_name,".blob.core.windows.net/",local.st_container_name])
  image_id                = "/subscriptions/8c2243fe-2eba-45da-bf61-0ceb475dcde8/resourceGroups/rg-rnd-product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly/versions/6.1.63"
  //ag_pip_dns_name         = "docsearch-dev-sinequa"
  queue_cluster           = null


  win_ad_name             = "sinequa.local"
  win_ad_login            = "azuredomainjoiner@sinequa.local"
  win_ad_pass             = data.azurerm_key_vault_secret.sinequa_ad_secret.value
  local_admins            = ["larde@sinequa.com","csest@sinequa.com"]
}


// Create the resource group
resource "azurerm_resource_group" "sinequa_rg" {
  name = local.resource_group_name
  location = local.region

  tags = {
    "sinequa-grid" = local.prefix
  }
}

// Specify an existing subnet of a virtual network
data "azurerm_subnet" "subnet_front" {
  name                 = "snet-front"
  resource_group_name  = "rg-www-network"
  virtual_network_name = "vnet-corp-www"
}

// Specify an existing subnet of a virtual network
data "azurerm_subnet" "subnet_app" {
  name                 = "snet-it"
  resource_group_name  = "rg-www-network"
  virtual_network_name = "vnet-corp-www"
}

// Specify an existing security group 
data "azurerm_network_security_group" "nsg_back" {
  name                 = "nsg_snet-it"
  resource_group_name  = "rg-www-network"
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
module "vm_primary_node1" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = "vm-${local.prefix}-${local.node1_name}"
  computer_name         = local.node1_name
  vm_size               = "Standard_D4s_v3"
  subnet_id             = data.azurerm_subnet.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  linked_to_application_gateway = false
  #availability_set_id   = null #data.azurerm_availability_set.sinequa_as.id
  #backend_address_pool_id = "" #data.azurerm_application_gateway.sinequa_ag.backend_address_pool[0].id
  network_security_group_id = data.azurerm_network_security_group.nsg_back.id
  pip                   = false

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "1"
    "sinequa-node"                        = local.node1_name
    "sinequa-webapp"                      = "WebAppDocDev"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.kv_st_services]
}


// Create Primary Node2
module "vm_node2" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = "vm-${local.prefix}-${local.node2_name}"
  computer_name         = local.node2_name
  vm_size               = "Standard_D4s_v3"
  subnet_id             = data.azurerm_subnet.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  linked_to_application_gateway = false
  #availability_set_id   = null #data.azurerm_availability_set.sinequa_as.id
  #backend_address_pool_id = "" #data.azurerm_application_gateway.sinequa_ag.backend_address_pool[0].id
  network_security_group_id = data.azurerm_network_security_group.nsg_back.id
  pip                   = false

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-node"                        = local.node2_name
    "sinequa-webapp"                      = "WebAppDocInternalDev"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.kv_st_services]
}


// vm-primary-node1 : Join AD 
module "vm_primary_node1_ad" {
  source                = "../../modules/ad"
  active_directory_name = local.win_ad_name
  ad_login              = local.win_ad_login
  ad_password           = local.win_ad_pass
  virtual_machine_id    = module.vm_primary_node1.vm.id
  local_admins          = local.local_admins

  depends_on = [module.vm_primary_node1]
}


// vm-node2 : Join AD 
module "vm_node2_ad" {
  source                = "../../modules/ad"
  active_directory_name = local.win_ad_name
  ad_login              = local.win_ad_login
  ad_password           = local.win_ad_pass
  virtual_machine_id    = module.vm_node2.vm.id
  local_admins          = local.local_admins

  depends_on = [module.vm_node2]
}


data "azuread_user" "csest" {
  user_principal_name = "csest@sinequa.com"
}

resource "azurerm_role_assignment" "sinequa_vm_role_cset" {
  scope                 = azurerm_resource_group.sinequa_rg.id
  role_definition_name  = "Contributor"
  principal_id          = data.azuread_user.csest.id
}

output "sinequa_admin_url" {
  value = "http://${module.vm_primary_node1.nic.private_ip_address}/admin"
}