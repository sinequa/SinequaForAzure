# destroy vm (os disk) & vmss
terraform destroy -auto-approve `
    -target module.vm-primary-node1.azurerm_virtual_machine.sinequa_vm `
    -target module.vmss-indexer1.azurerm_windows_virtual_machine_scale_set.sinequa_vmss

# recreate them
terraform apply -auto-approve