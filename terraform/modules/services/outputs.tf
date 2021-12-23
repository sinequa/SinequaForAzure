
output "st_premium" {
  value = azurerm_storage_account.sinequa_st_premium
  sensitive = true
}

output "st_hot" {
  value = azurerm_storage_account.sinequa_st_hot
  sensitive = true
}

output "kv" {
  value = azurerm_key_vault.sinequa_kv
  sensitive = true
}

output "hot_container" {
  value = azurerm_storage_container.sinequa_st_hot_container
  sensitive = true
}

output "premium_container" {
  value = azurerm_storage_container.sinequa_st_premium_container
  sensitive = true
}

output "id" {
  value = azurerm_user_assigned_identity.identity
  sensitive = true
}
