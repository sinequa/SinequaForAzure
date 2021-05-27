# ARM

Sinequa For Azure (S4A) ARM is a set of ARM templates used for a Sinequa ES grid deployment.

#### Table of contents
1. [Deploy a Sinequa Grid](#deploy)<br>
2. [Node specialization](#specify)<br>
3. [Add a node to a Sinequa Grid](#add)<br>
   3.1. [Add a VM Node](#add_vm)<br>
   3.2. [Add a VMSS Node](#add_vmss)<br>
4. [Update a Sinequa Grid](#update)<br> 
   4.1. [Update a VM Node](#update_vm)<br>
   4.2. [Update a VM Node](#update_vmss)<br>
   
This main ARM template deploys a complete Sinequa grid.

Note: These ARM templates are those used for the Azure Marketplace. They are designed for being called from an URI (due to the nested templates).


## Diagram

![Sinequa For Azure Deployment](../images/S4A_Default_ARM.png)

## Scripts

### 1. Deploy a Sinequa Grid <a name="deploy">

ARM (Azure Resource Manager) deployment is used to deploy a grid from the Marketplace or from your own image.

```powershell
sinequa-for-azure-deploy-grid.ps1
    [[-subscriptionId] <String>]    
    [-templateUri <String>]    
    [-templateParameterFile <SecureString>]    
    [[-resourceGroupName] <String>]    
    [[-galleryName] <String>]    
    [[-imageDefinitionName] <String>]    
    [[-imageName] <String>]    
    [[-version] <String>]
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-deploy-grid.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -templateUri https://sinequabuilds.blob.core.windows.net/arm/mainTemplate.json
```
This script deploys the following files:
* `mainTemplate.json`: ARM template that can instantiate a complete grid with:
  * 1 application gateway
  * 1 availability set
  * 1 key vault
  * 2 network security group
  * 1 public IP address
  * 1 storage account
  * 1 virtual machine scale sets
  * 1 virtual network
  * 1 or 3 virtual machines for primary nodes
* `mainTemplate.parameters.json`: paramaters that should be updated.

| Parameter              | Default Value                  | Description       |
| ---------------------- | ------------------------------ | ----------------- |
| prefix                 | sq                             | Prefix of object names. |
| location               | Location of the resource group |
| adminUsername 	     | sinequa                        | Windows user. |
| adminPassword 	     |                                | Windows user password. |
| vmSize 		     |                                | vmSize of primary nodes. |
| vmIndexerSize 	     |                                | vmSize of the indexer scale set. Default |
| vmIndexerScaleSetSize	     | 1                              | Indexer Scale Set size (instances). |
| primaryNodeCount 	     | 3                              | Number of primary nodes (1 or 3). |
| certificateBase64          |                                | Certificate file (.pfx) in base64 format for HTTPS. |
| certificatePassword        |                                | Password of the certificate. |
| license                    |                                | Sinequa license. |
| imageReferenceId           | none                           | ID of the custom image to use. If empty, the marketplace will be used.<br> Example: "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly" |
| virtualNetworkName         |                                | Virtual network object. |
| _artifactsLocation     | deployment().properties.templateLink.uri | (do not change it) used for nested templates |
| _artifactsLocationSasToken |                            | (do not change it) used for nested templates |

Note: Some variables could be change like:
* node1_name
* node2_name
* node2_name

### 2. Node Specialization <a name="specify">

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


### 3. Add a Node to a Sinequa Grid <a name="add">	
#### 3.1. Add a VM Node <a name="add_vm"> 
In `mainTemplate.json`, add a new resource using the nested template named `vm.json` (templateLink.uri= "[variables('vm_template_uri')]") and re-deploy.

#### 3.2. Add a VMSS Node <a name="add_vmss"> 
In `mainTemplate.json`, add a new resource using the nested template named `vmss.json` (templateLink.uri= "[variables('vmss_template_uri')]") and re-deploy.

### 4. Update a Sinequa Grid <a name="update"> 
#### 4.1. Update a VM Node <a name="update_vm">   
This is not possible via ARM. You have to update your VM manually via a classical Sinequa update inside the VM.

#### 4.2. Update a VMSS Node <a name="update_vmss">    
This is not possible via ARM. You have to update your VMSS manually by deleting the VMSS and execute a new deployment.

