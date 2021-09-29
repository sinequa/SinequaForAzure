
// Enable Azure AD Login (requires vm system identity=true)
resource "azurerm_virtual_machine_extension" "aadLoginExtensionName" {
  count                = var.is_vm?1:0
  name                 = "aadLoginExtensionName"
  virtual_machine_id   = var.virtual_machine_id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true  

  settings = <<SETTINGS
  {
      "mdmId": ""
  }
  SETTINGS
}

resource "azurerm_virtual_machine_scale_set_extension" "aadLoginExtensionName" {
  count                = var.is_vm ? 0:1
  name                 = "aadLoginExtensionName"
  virtual_machine_scale_set_id   = var.virtual_machine_id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true  

  settings = <<SETTINGS
  {
      "mdmId": ""
  }
  SETTINGS
}


data "azuread_user" "users" {
  for_each            = toset(var.local_admins)
  user_principal_name = each.value
}

// IAM
resource "azurerm_role_assignment" "sinequa_vm_role_user" {
  for_each              = data.azuread_user.users
  scope                 = var.virtual_machine_id
  role_definition_name  = "Virtual Machine Administrator Login"
  principal_id          = each.value.id
}

/*
// Add local azure accounts as local admins for RDP 
// ... and add dns suffix
resource "azurerm_virtual_machine_extension" "powershell_script" {
  count                = var.is_vm?1:0
  name                 = "ps_script_for_add"
  virtual_machine_id   = var.virtual_machine_id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted \"Get-DnsClient -ConnectionSpecificSuffix reddog.microsoft.com | Set-DnsClient -ConnectionSpecificSuffix sinequa.local ; Add-LocalGroupMember -Group Administrators -Member AzureAd\\${join(", AzureAd\\\\",var.local_admins)}\""
  }
  SETTINGS

  depends_on = [azurerm_virtual_machine_extension.aadLoginExtensionName]
}

resource "azurerm_virtual_machine_scale_set_extension" "powershell_script" {
  count                = var.is_vm?0:1
  name                 = "ps_script_for_add"
  virtual_machine_scale_set_id   = var.virtual_machine_id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted \"Get-DnsClient -ConnectionSpecificSuffix reddog.microsoft.com | Set-DnsClient -ConnectionSpecificSuffix sinequa.local ; Add-LocalGroupMember -Group Administrators -Member AzureAd\\${join(", AzureAd\\\\",var.local_admins)}\""
  }
  SETTINGS

  depends_on = [azurerm_virtual_machine_scale_set_extension.aadLoginExtensionName]
}
*/