output "vm" {
  value = azurerm_virtual_machine.sinequa_vm
  sensitive = true
}

output "nic" {
  value = azurerm_network_interface.sinequa_vm_nic
  sensitive = false
}
