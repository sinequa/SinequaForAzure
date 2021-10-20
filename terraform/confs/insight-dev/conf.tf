terraform {
  backend "azurerm" {
    resource_group_name = "rg-www-tf"
    storage_account_name  = "satfwwwsnqa"
    container_name  = "terraform"
    key = "tf.insight-dev.tfstate"
  }
}
provider "azuread" {}


provider "azurerm" {
  version = "=2.78.0" // regression : https://github.com/hashicorp/terraform-provider-azurerm/issues/13652
  partner_id = "947f5924-5e20-4f0a-96eb-808371995ac8" // Sinequa Tracking ID
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
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

resource "random_password" "sq_passwd" {
  length      = 24
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false

  keepers = {
    domain_name_label = local.prefix
  }
}
resource "random_password" "srpc" {
  length      = 24
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false

  keepers = {
    domain_name_label = local.prefix
  }
}

data "azurerm_client_config" "current" {}

// Specify an existing subnet of a virtual network
data "azurerm_key_vault" "kv-snqa" {
  name                 = "kv-snqa-management-key"
  resource_group_name  = "rg-www-security"
}



locals {
  region                  = "francecentral"
  resource_group_name     = "rg-www-insight-dev"
  prefix                  = "sq"
  os_admin_username       = "sinequa"
  os_admin_password       = element(concat(random_password.passwd.*.result, [""]), 0)

  sinequa_default_admin_password = element(concat(random_password.sq_passwd.*.result, [""]), 0)
  srpc_secret             = element(concat(random_password.srpc.*.result, [""]), 0)
  license                 = fileexists("../sinequa.license.txt")?file("../sinequa.license.txt"):""
  node1_name              = "insight-1"  
  node1_osname            = "vm-insight-dev1"
  node1_fqdn              = join("",[local.node1_osname, ".sinequa.local"])
  node1_private_ip_address= "10.200.5.11"  
  node2_name              = "insight-2"  
  node2_osname            = "vm-insight-dev2"    
  node2_fqdn              = join("",[local.node2_osname, ".sinequa.local"])
  node2_private_ip_address= "10.200.5.12"  
  node3_name              = "insight-3"  
  node3_osname            = "vm-insight-dev3"
  node3_fqdn              = join("",[local.node3_osname,".sinequa.local"])
  
  node3_private_ip_address= "10.200.5.13"  
  primary_nodes           = join("",["1=srpc://", local.node1_fqdn ,":10301",";2=srpc://", local.node2_fqdn ,":10301",";3=srpc://", local.node3_fqdn ,":10301"])
  st_name                 = substr(join("",["st",replace(md5(local.resource_group_name),"-","")]),0,24)
  kv_name                 = substr(join("-",["kv",local.prefix,replace(md5(local.resource_group_name),"-","")]),0,24)
  queue_cluster           = "QueueClusterInsight(${local.node1_name},${local.node2_name},${local.node3_name})"
  st_container_name       = "sinequa"
  data_storage_root       = "grids/insight-dev/"

  data_storage_url        = join("",["https://",local.st_name,".blob.core.windows.net/",local.st_container_name,"/", local.data_storage_root])
  image_id                = "/subscriptions/8c2243fe-2eba-45da-bf61-0ceb475dcde8/resourceGroups/rg-rnd-product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-${var.repo}/versions/${replace(var.version_number,"/^[0-9]+./","")}"
  
  local_admins            = ["larde@sinequa.com","csest@sinequa.com","manigot@sinequa.com"]
  vmss_indeder_capacity   = 3
}



// Create the resource group
resource "azurerm_resource_group" "sinequa_rg" {
  name = local.resource_group_name
  location = local.region

  tags = {
    "sinequa-grid" = local.prefix
    "version"      = var.version_number
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
  data_storage_root     = local.data_storage_root
  default_admin_password = local.sinequa_default_admin_password

  blob_sinequa_primary_nodes = local.primary_nodes 
  blob_sinequa_beta          = true
  blob_sinequa_keyvault      = local.kv_name
  blob_sinequa_queuecluster  = local.queue_cluster
  blob_sinequa_authentication_secret = local.srpc_secret
  blob_sinequa_authentication_enabled = true
  blob_sinequa_version       = var.version_number

  depends_on = [azurerm_resource_group.sinequa_rg]
}

// Create Primary Node1
module "vm-primary-node1" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.node1_osname
  computer_name         = local.node1_osname
  vm_size               = "Standard_B2ms"
  subnet_id             = data.azurerm_subnet.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  linked_to_application_gateway = false
  network_security_group_id = data.azurerm_network_security_group.nsg_back.id
  pip                   = false
  private_ip_address    = local.node1_private_ip_address

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "1"
    "sinequa-node"                        = local.node1_name
    "sinequa-webapp"                      = "WebApp1"
    "sinequa-alpha"                       = "true"
    "sinequa-hostname-override"           = local.node1_fqdn
    "version"                             = var.version_number    
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.kv_st_services]
}

// vm-primary-node1 : Join Azure AD 
module "vm-primary-node1-aad" {
  source                = "../../modules/aad"
  virtual_machine_id    = module.vm-primary-node1.vm.id
  local_admins          = local.local_admins

  depends_on = [module.vm-primary-node1]
}

// Create Primary Node2
module "vm-primary-node2" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.node2_osname
  computer_name         = local.node2_osname
  vm_size               = "Standard_B2ms"
  subnet_id             = data.azurerm_subnet.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  linked_to_application_gateway = false
  network_security_group_id = data.azurerm_network_security_group.nsg_back.id
  pip                   = false
  private_ip_address    = local.node2_private_ip_address

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "2"
    "sinequa-node"                        = local.node2_name
    "sinequa-webapp"                      = "WebApp2"
    "sinequa-alpha"                       = "true"
    "sinequa-hostname-override"           = local.node2_fqdn
    "version"                             = var.version_number    
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.kv_st_services]
}

// vm-primary-node2 : Join Azure AD 
module "vm-primary-node2-aad" {
  source                = "../../modules/aad"
  virtual_machine_id    = module.vm-primary-node2.vm.id
  local_admins          = local.local_admins

  depends_on = [module.vm-primary-node2]
}


// Create Primary Node3
module "vm-primary-node3" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = local.node3_osname
  computer_name         = local.node3_osname
  vm_size               = "Standard_B2ms"
  subnet_id             = data.azurerm_subnet.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  linked_to_application_gateway = false
  network_security_group_id = data.azurerm_network_security_group.nsg_back.id
  pip                   = false
  private_ip_address    = local.node3_private_ip_address

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-primary-node-id"             = "3"
    "sinequa-node"                        = local.node3_name
    "sinequa-alpha"                       = "true"
    "sinequa-hostname-override"           = local.node3_fqdn
    "sinequa-authentication-enabled"      = "true"
    "version"                             = var.version_number    
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.kv_st_services]
}

// vm-primary-node3 : Join Azure AD 
module "vm-primary-node3-aad" {
  source                = "../../modules/aad"
  virtual_machine_id    = module.vm-primary-node3.vm.id
  local_admins          = local.local_admins

  depends_on = [module.vm-primary-node3]
}

// Create Indexer Scale Set
module "vmss-indexer1" {
  source                = "../../modules/vmss"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vmss_name             = "nodevmss-indexer"
  computer_name_prefix  = "indexer"
  vmss_size             = "Standard_B2ms"
  subnet_id             = data.azurerm_subnet.subnet_app.id
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  network_security_group_id = data.azurerm_network_security_group.nsg_back.id

  primary_node_vm_principal_ids = {
    "1" = module.vm-primary-node1.vm.identity[0].principal_id
    "2" = module.vm-primary-node2.vm.identity[0].principal_id
    "3" = module.vm-primary-node3.vm.identity[0].principal_id
  }

  vmss_capacity         = local.vmss_indeder_capacity

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-node"                        = "insight-dynamic-node"
    "sinequa-indexer"                     = "indexer-dynamic"
    "sinequa-alpha"                       = "true"
    "version"                             = var.version_number    
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.kv_st_services,module.vm-primary-node1,module.vm-primary-node2,module.vm-primary-node3]
}


// vm-primary-node3 : Join Azure AD 
module "vmss-indexer-aad" {
  source                = "../../modules/aad"
  virtual_machine_id    = module.vmss-indexer1.vmss.id
  is_vm                 = false

  depends_on = [module.vm-primary-node3]
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
  value = "http://${module.vm-primary-node1.nic.private_ip_address}/admin"
}