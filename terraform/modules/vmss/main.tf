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
    type                = "UserAssigned"
    identity_ids        = [var.user_identity_id]
  }

}


resource "azurerm_role_assignment" "sinequa_vmss_role_vmss" {
  scope                 = azurerm_windows_virtual_machine_scale_set.sinequa_vmss.id
  role_definition_name  = "Contributor"
  principal_id          = var.user_identity_principal_id
}

