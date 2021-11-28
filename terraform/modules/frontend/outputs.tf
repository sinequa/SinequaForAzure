output "ag" {
  value =  azurerm_application_gateway.sinequa_ag
  sensitive = true
}

output "as" {
  value =  azurerm_availability_set.sinequa_as
  sensitive = true
}

output "pip" {
  value =  azurerm_public_ip.sinequa_ag_pip
  sensitive = false
}