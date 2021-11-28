output "vm" {
  value = azurerm_virtual_machine.sinequa_vm
}

output "nic" {
  value = azurerm_network_interface.sinequa_vm_nic
  sensitive = false
}

output "pip" {
  value = azurerm_public_ip.sinequa_vm_pip
  sensitive = false
}
