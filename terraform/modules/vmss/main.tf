resource "azurerm_windows_virtual_machine_scale_set" "sinequa_vmss" {
  name                      = var.vmss_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  tags                      = var.tags
  admin_username            = var.admin_username
  admin_password            = var.admin_password
  instances                 = var.vmss_capacity
  sku                       = var.vmss_size
  computer_name_prefix      = var.computer_name_prefix
  timezone                  = "W. Europe Standard Time"
  provision_vm_agent        = true
  source_image_id           = var.image_id
  
  os_disk {
    caching                 = "ReadWrite"
    storage_account_type    = var.os_disk_type
  }
 
  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "ipconfig"
      primary                                = true
      subnet_id                              = var.subnet_id
    }
  }

  identity {
    type                = "SystemAssigned"
  }

}

resource "azurerm_role_assignment" "sinequa_kv_role_vmss" {
  scope                 = var.key_vault_id
  role_definition_name  = "key Vault Secrets Officer"
  principal_id          = azurerm_windows_virtual_machine_scale_set.sinequa_vmss.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_account_id" {
  scope                 = var.storage_account_id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = azurerm_windows_virtual_machine_scale_set.sinequa_vmss.identity[0].principal_id
}

resource "azurerm_role_assignment" "sinequa_vmss_role_vm" {
  for_each              = var.primary_node_vm_principal_ids
  scope                 = azurerm_windows_virtual_machine_scale_set.sinequa_vmss.id
  role_definition_name  = "Contributor"
  principal_id          = each.value
}

resource "azurerm_role_assignment" "sinequa_vmss_role_vmss" {
  scope                 = azurerm_windows_virtual_machine_scale_set.sinequa_vmss.id
  role_definition_name  = "Contributor"
  principal_id          = azurerm_windows_virtual_machine_scale_set.sinequa_vmss.identity[0].principal_id
}

