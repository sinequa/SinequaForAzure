
resource "azurerm_virtual_machine_extension" "join_ad" {
  count                = var.is_vm?1:0
  name                 = "join-ad"
  virtual_machine_id   = var.virtual_machine_id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = <<SETTINGS
  {
      "Name": "${var.active_directory_name}",
      "User": "${var.ad_login}",
      "Restart": "false",
      "Options": "3"
  }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
      "Password": "${var.ad_password}"
  }
  PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_scale_set_extension" "join_ad" {
  count                = var.is_vm?0:1
  name                 = "join-ad"
  virtual_machine_scale_set_id   = var.virtual_machine_id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = <<SETTINGS
  {
      "Name": "${var.active_directory_name}",
      "User": "${var.ad_login}",
      "Restart": "false",
      "Options": "3"
  }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
      "Password": "${var.ad_password}"
  }
  PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "powershell_add_members_to_group" {
  count                = var.is_vm?1:0
  name                 = "ps_add_members_to_group"
  virtual_machine_id   = var.virtual_machine_id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted Add-LocalGroupMember -Group Administrators -Member ${join(", ",var.local_admins)}"
  }
  SETTINGS

  depends_on = [azurerm_virtual_machine_extension.join_ad]
}

resource "azurerm_virtual_machine_scale_set_extension" "powershell_add_members_to_group" {
  count                = var.is_vm?0:1
  name                 = "ps_add_members_to_group"
  virtual_machine_scale_set_id   = var.virtual_machine_id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted Add-LocalGroupMember -Group Administrators -Member ${join(", ",var.local_admins)}"
  }
  SETTINGS

  depends_on = [azurerm_virtual_machine_scale_set_extension.join_ad]
}