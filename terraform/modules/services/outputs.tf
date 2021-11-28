
output "st" {
  value = azurerm_storage_account.sinequa_st
  sensitive = true
}

output "kv" {
  value = azurerm_key_vault.sinequa_kv
  sensitive = true
}

output "container" {
  value = azurerm_storage_container.sinequa_st_container
  sensitive = true
}

output "id" {
  value = azurerm_user_assigned_identity.identity
  sensitive = true
}
