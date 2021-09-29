output "vmss" {
  value = azurerm_windows_virtual_machine_scale_set.sinequa_vmss
  sensitive = true
}
