locals {
  os_disk_name      = "osdisk-${var.vm_name}"    
  data_disk_name    = "datadisk-${var.vm_name}"    
}

resource "azurerm_public_ip" "sinequa_vm_pip" {
  count                     = var.pip?1:0
  name                      = "pip-${var.vm_name}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  allocation_method         = "Dynamic"
  sku                       = "Basic"  
}

resource "azurerm_network_interface" "sinequa_vm_nic" {
  name                      = "nic-${var.vm_name}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                      = var.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.pip?azurerm_public_ip.sinequa_vm_pip[0].id:null
  }
}


resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "sinequa_vm_to_ag" {
  count                   = var.linked_to_application_gateway?0:1
  network_interface_id    = azurerm_network_interface.sinequa_vm_nic.id
  ip_configuration_name   = azurerm_network_interface.sinequa_vm_nic.ip_configuration[0].name
  backend_address_pool_id = var.backend_address_pool_id

  depends_on = [azurerm_network_interface.sinequa_vm_nic]
}

resource "azurerm_virtual_machine" "sinequa_vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.sinequa_vm_nic.id]
  vm_size               = var.vm_size
  availability_set_id   = var.availability_set_id
  delete_os_disk_on_termination = true
  tags                      = var.tags

  os_profile_windows_config {
    provision_vm_agent  = true
    enable_automatic_upgrades = false
    timezone            = "W. Europe Standard Time"
  }

  identity {
    type                = "SystemAssigned"
  }
  
  storage_image_reference {
   id                   = var.image_id
  }

  storage_os_disk {
    name              = local.os_disk_name
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.os_disk_type
  }

  os_profile {
    computer_name  = var.computer_name
    admin_username = var.admin_username
    admin_password = var.admin_password
  }


  
}

resource "azurerm_managed_disk" "sinequa_vm_datadisk" {
  count                = length(var.datadisk_ids) == 0?1:0
  name                 = local.data_disk_name
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "sinequa_vm_datadisk_attach" {
  count              = length(var.datadisk_ids) == 0?1:0
  managed_disk_id    = azurerm_managed_disk.sinequa_vm_datadisk[0].id
  virtual_machine_id = azurerm_virtual_machine.sinequa_vm.id
  lun                = "0"
  caching            = "ReadOnly"
}


resource "azurerm_virtual_machine_data_disk_attachment" "sinequa_vm_datadiskids_attach" {
  for_each           = toset(var.datadisk_ids)
  managed_disk_id    = each.key
  virtual_machine_id = azurerm_virtual_machine.sinequa_vm.id
  lun                = index(var.datadisk_ids, each.key)
  caching            = "ReadOnly"
}

resource "azurerm_network_interface_security_group_association" "sinequa_nic_nsg" {
  network_interface_id      = azurerm_network_interface.sinequa_vm_nic.id
  network_security_group_id = var.network_security_group_id
}

resource "azurerm_role_assignment" "sinequa_kv_role_vm" {
  scope                 = var.key_vault_id
  role_definition_name  = "key Vault Secrets Officer"
  principal_id          = azurerm_virtual_machine.sinequa_vm.identity[0].principal_id
  skip_service_principal_aad_check  = true
}

resource "azurerm_role_assignment" "sinequa_st_role_vm" {
  scope                 = var.storage_account_id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = azurerm_virtual_machine.sinequa_vm.identity[0].principal_id
  skip_service_principal_aad_check  = true
}

