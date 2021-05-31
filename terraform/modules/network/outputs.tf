output "vnet" {
  value = azurerm_virtual_network.sinequa_vnet
  sensitive = true
}

output "nsg_app" {
  value = azurerm_network_security_group.sinequa_nsg_app
  sensitive = true
}

output "nsg_front" {
  value = azurerm_network_security_group.sinequa_nsg_front
  sensitive = true
}

output "subnet_app" {
  value = azurerm_subnet.subnet_app
  sensitive = true
}

output "subnet_front" {
  value = azurerm_subnet.subnet_front
  sensitive = true
}
