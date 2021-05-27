# Terraform

Sinequa For Azure (S4A) Terraform is a set of Terraform scripts used for a Sinequa ES grid deployment.

#### Table of contents
0. [Prerequisite](#prerequisite)<br>
1. [Terraform Modules](#modules)<br>
2. [complete_grid Sample](#complete_grid)<br>
2.1. [Nodes specialization](#specify)<br>
2.2. [Add Nodes to a Sinequa Grid](#add)<br>
2.2.1.  [Add a VM Node](#add_vm)<br>
2.2.2.  [Add a VMSS Node](#add_vmss)<br>
2.2.3.  [Update a Sinequa Grid](#update)<br>

   

## Diagram

![Sinequa For Azure Deployment](../images/S4A_Default_ARM.png)

## Scripts

### 0. Prerequisite <a name="prerequisite">

* https://www.terraform.io/downloads.html

### 1. Terraform Modules <a name="modules">

In the modules folder, scripts are provided to build blocks:

* **frontend**: Deploys an `Application Gateway` with a `Public IP`

| Variables                | Description |
| ------------------------ | ----------- |
| location                 | Azure location. |
| resource_group_name      | Resource group for deployment. |
| availability_set_name    | Availability set name to create. Needed for the application gateway. |
| application_gateway_name | Name of the application gateway to create. |
| subnet_id                | Subnet ID for the application gateway. Used only for HTTPS from end-users. |
| certificate              | Certificate object for SSL. Could be directly the content of a .pfx file or a certificate from a key vault. |
| dns_name                 | DNS name prefix for the application gateway public IP. |
| kv_identity_reader       | Identity for reading the key vault certificate (if used). |
| tags                     | Azure tags. |

* **network**: Deploys `Network Security Groups` and `Virtual Network`

| Variables                | Description |
| ------------------------ | ----------- |
| location                 | Azure location. |
| resource_group_name      | Resource Group for deployment. |
| vnet_name                | Virtual Network to create. |
| subnet_app_name          | Subnet for VM & VMSS. |
| subnet_front_name        | Subnet for the application gateway. |
| nsg_app_name             | Network security group for VM & VMSS  (RDP rule). |
| nsg_front_name           | Network security group for the application gateway (HTTPS rule). |
| tags                     | Azure tags. |

* **service**: Deploys a `Key Vault` and a `Storage Account`

| Variables                | Description |
| ------------------------ | ----------- |
| location                 | Azure location. |
| resource_group_name      | Resource group for deployment. |
| kv_name                  | Key vault to create. |
| st_name                  | Storage account to create. |
| container_name           | Container in the storage account. |
| license                  | Sinequa license to be uploaded in the key vault as secret. |
| blob_sinequa_primary_nodes | Sinequa Cloud Vars for sRPC connection string of primary nodes. |
| blob_sinequa_beta        | Sinequa Cloud Vars to enable beta features. |
| blob_sinequa_keyvault    | Sinequa Cloud Vars to specify the key vault URL. |
| blob_sinequa_queuecluster | Sinequa Cloud Vars to create a QueueCluster. |
| tags                     | Azure tags. |

* **service**: Deploys a `Key Vault` and a `Storage Account`

| Variables                | Description |
| ------------------------ | ----------- |
| location                 | Azure location. |
| resource_group_name      | Resource Group for deployment. |
| kv_name                  | Key Vault to create. |
| st_name                  | Storage account to create. |
| container_name           | Container in the storage account. |
| license                  | Sinequa license to be uploaded in the key vault as secret. |
| blob_sinequa_primary_nodes | Sinequa Cloud Vars for sRPC connection string of primary nodes. |
| blob_sinequa_beta        | Sinequa Cloud Vars to enable beta features. |
| blob_sinequa_keyvault    | Sinequa Cloud Vars to specify the key vault URL. |
| blob_sinequa_queuecluster | Sinequa Cloud Vars to create a queue cluster. |
| tags                     | Azure tags |

* **vm**: Deploys a `Virtual Machine`

| Variables                | Description |
| ------------------------ | ----------- |
| location                 | Azure location. |
| resource_group_name      | Resource group for deployment. |
| vm_name                  | Name of the VM. |
| vm_size                  | VM size. |
| computer_name            | VM OS computer name. |
| subnet_id                | Subnet ID of the VM. |
| image_id                 | Sinequa image to use (image or image definition) to create the VM. |
| os_disk_type             | OS disk type. |
| data_disk_type           | Size of the data disk. |
| admin_username           | OS user login. |
| admin_password           | OS user password. |
| key_vault_id             | Key vault used for secrets. Needed to grant read secrets access on the VM identity. |
| storage_account_id       | Storage account used for Sinequa Cloud Var and Container. Needed to grant read/write access on the VM identity. |
| availability_set_id      | Availaibility set for the application gateway. |
| pip                      | Add a public IP if needed. |
| linked_to_application_gateway | The VM is linked to an application gateway? |
| backend_address_pool_id  | Backend Address Pool ID of the application gateway. Required for VM with WebApp. |
| network_security_group_id | Network security group of the VM. |
| datadisk_ids             | Use existing data disk. |
| tags                     | Azure tags to specify Sinequa roles. |

* **vmss**: Deploys a `Virtual Machine ScaleSet`

| Variables                | Description |
| ------------------------ | ----------- |
| location                 | Azure location. |
| resource_group_name      | Resource group for deployment. |
| vmss_name                | Name of the VMSS. |
| vmss_size                | VMSS size. |
| vmss_capacity            | Number of instances of the VMSS. |
| computer_name_prefix     | VMSS OS computer name prefix. |
| subnet_id                | Subnet ID of the VM. |
| image_id                 | Sinequa image to use (image or image definition) to create the VMSS. |
| os_disk_type             | OS disk type. |
| admin_username           | OS user login. |
| admin_password           | OS user password. |
| key_vault_id             | Key vault used for secrets. Needed to grant read secrets access on the VMSS identity. |
| storage_account_id       | Storage account used for Sinequa Cloud Var and Container. Needed to grant read/write access on the VMSS identity. |
| network_security_group_id | Network security group of the VM. |
| tags                     | Azure tags to specify Sinequa roles. |

### 2. complete_grid sample <a name="complete_grid">

`complete_grid` is a a deployment of all modules with these objects:
 * 1 Application gateway
 * 1 Availability set
 * 1 Key vault
 * 2 Network security groups
 * 1 Public IP address
 * 1 Storage account
 * 1 Virtual machine scale sets for Indexer
 * 1 Virtual network
 * 3 Virtual Machines for primary nodes


```powershell
PS C:\> .\terraform init
PS C:\> .\terraform validate
PS C:\> .\terraform apply
```
#####  2.1. Nodes Specialization <a name="specify">

* **Cloud Tags of `vm-node1`**
    | Name                     | Value |
    | ------------------------ | ----- |
    | sinequa-auto-disk	       | auto |
	| sinequa-path		       | f:\sinequa |
	| sinequa-data-storage-url | https://`{storage account name}`.blob.core.windows.net/sinequa |
	| sinequa-primary-node-id  | 1 |
	| sinequa-node	           | vm-node1 |
	| sinequa-webapp 		   | webapp1 | 
	| sinequa-engine		   | engine1 |

* **Cloud Tags of `vm-node2`**
    | Name                     | Value |
    | ------------------------ | ----- |
    | sinequa-auto-disk	       | auto |
	| sinequa-path		       | f:\sinequa |
	| sinequa-data-storage-url | https://`{storage account name}`.blob.core.windows.net/sinequa |
	| sinequa-primary-node-id  | 2 |
	| sinequa-node	           | vm-node2 |
	| sinequa-webapp 		   | webapp2 |
	| sinequa-engine		   | engine2 |

* **Cloud Tags of `vm-node3`**
    | Name                     | Value |
    | ------------------------ | ----- |
    | sinequa-auto-disk	       | auto |
	| sinequa-path		       | f:\sinequa |
	| sinequa-data-storage-url | https://`{storage account name}`.blob.core.windows.net/sinequa |
	| sinequa-primary-node-id  | 3 |
	| sinequa-node	           | vm-node3 |
	| sinequa-webapp 		   | webapp3 |

* **Cloud Tags of `vmss-indexer`**
    | Name                     | Value |
    | ------------------------ | ----- |
    | sinequa-auto-disk	       | auto |
	| sinequa-path		       | f:\sinequa |
	| sinequa-data-storage-url | https://`{storage account name}`.blob.core.windows.net/sinequa |
	| sinequa-node	           | vm-indexer |
	| sinequa-webapp 		   | indexer1 |

* **Cloud Vars (in Storage Account)**
    | Name                     | Value |
    | ------------------------ | ----- |
	| sinequa-primary-nodes    | 1=srpc://vm-node1:10300;2=srpc://vm-node2:10300;3=srpc://vm-node3=10300 |
    | sinequa-beta             | true |
	| sinequa-keyvault 	       | `{Key Vault Name}` |
	| sinequa-queue-cluster    | QueueCluster1(vm-node1,vm-node2,vm-node3) |
	
* **Cloud secrets (Secrets in Key Vault)**
    | Name                     | Value |
    | ------------------------ | ----- |
	| sinequa-license		   | `{License}` |

### 2.2. Add nodes to a Sinequa Grid <a name="add">	
#### 2.2.1 Add a VM Node <a name="add_vm"> 
In `conf.tf` add a new resource using the `vm` module and re-deploy.

```terraform
// Create VM Node 4

locals  {
    node4_name          = "node4"
}

module "vm-node4" {
  source                = "../../modules/vm"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vm_name               = "vm-${local.prefix}-${local.node4_name}"
  computer_name         = local.node4_name
  vm_size               = "Standard_E8s_v3"
  subnet_id             = module.network.vnet.subnet.*.id[0]
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  network_security_group_id = module.network.nsg_app.id
  pip                   = true

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-auto-disk"                   = "auto"
    "sinequa-path"                        = "F:\\sinequa"
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-node"                        = local.node4_name
    "sinequa-engine"                      = "engine4"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services, module.frontend]
}
```

```powershell
PS C:\> .\terraform apply
```


#### 2.2.2 Add a VMSS Node <a name="add_vmss"> 
In `conf.tf` add a new resource using the `vmss` module and re-deploy.

```terraform
// Create Connector Scale Set
module "vmss-connectors" {
  source                = "../../modules/vmss"
  resource_group_name   = azurerm_resource_group.sinequa_rg.name
  location              = azurerm_resource_group.sinequa_rg.location
  vmss_name             = "vmss-${local.prefix}-connectors"
  computer_name_prefix  = "cnt"
  vmss_size             = "Standard_B2s"
  subnet_id             = module.network.vnet.subnet.*.id[0]
  image_id              = local.image_id
  admin_username        = local.os_admin_username
  admin_password        = local.os_admin_password
  key_vault_id          = module.kv_st_services.kv.id
  storage_account_id    = module.kv_st_services.st.id
  network_security_group_id = module.network.nsg_app.id

  tags = {
    "sinequa-grid"                        = local.prefix
    "sinequa-data-storage-url"            = local.data_storage_url
    "sinequa-node"                        = "connector1"
  }

  depends_on = [azurerm_resource_group.sinequa_rg, module.network, module.kv_st_services]
}
```

### 2.2.3. Update a Sinequa Grid <a name="update"> 
For updating a complete grid, just change the `local.image_id` with the new version, and re-deploy

```terraform
image_id                = "/subscriptions/e88f44fe-533b-4811-a972-5f6a692b0730/resourceGroups/Product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly/versions/6.1.42"
```

```powershell
PS C:\> .\terraform apply
```
