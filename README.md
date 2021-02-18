# SinequaForAzure

Sinequa For Azure (S4A) is a set of Azure optimizations for reducing cost and improving reliability and performances

In the script folder, different PowerShell scripts allow you to deploy and manage a Sinequa Grid based on the Official Sinequa Marketplace Image or by your own Sinequa Custom Image

Depending on where are located Sinequa Images and where you deploy a Grid, different sources can be used:
- Deploy a Grid in an another Tenant than your image: Only Marketplace can be used (Official Image, not a custom image)
- Deploy a Grid in the same Tenant but not in the same subscription: Marketplace or Image Shared Image Gallery 
- Deploy a Grid in the same subscription: Marketplace or Image Shared Image Gallery or Image

## Scripts
### 1. Create Your Own Sinequa Image

#### 1.1 Create the Base Image
This first image is a Base Windows Image including all pre-requisite that you want to install before build a specific version of Sinequa

```powershell
sinequa-for-azure-build-base-image.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-imageResourceGroupName] <String>]    
    [[-imageName] <String>]    
    [[-tempResourceGroupName] <String>]    
    [[-osUsername] <String>]    
    [[-osPassword] <Securetring>]       
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-build-base-image.ps1 -tenantId 00000000-0000-0000-0000-000000000000 -subscriptionId 00000000-0000-0000-0000-000000000000
```

This script will run these "Custom Sript Extensions":
* sinequa-az-cse-install-programs.ps1, that could be customized
* sinequa-az-cse-windows-update.ps1: Apply Windows Updates

#### 1.2 Create a Sinequa Version Image
Create an Sinequa Image from a distribution "sinequa.11.zip". This script will pre-install sinequa (unzip & install services)

```powershell
sinequa-for-azure-build-image.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-imageResourceGroupName] <String>]    
    [[-baseImageName] <String>]    
    [[-imageName] <String>]    
    [[-tempResourceGroupName] <String>]    
    [[-version] <String>]
    [-localFile] <String>]
    [-fileUrl] <String>]
    [[-osUsername] <String>]    
    [[-osPassword] <Securetring>]       
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-build-image.ps1 -version 11.5.1.54 -tempResourceGroupName temp-sinequa-image-11.5.1.54 -imageName sinequa-nightly-11.5.1.54 -localfile c:\builds\11.5.1.54\sinequa.11.zip -subscriptionId 00000000-0000-0000-0000-000000000000
```

#### 1.3 Publish an Image in a Shared Image Gallery (Optional)
This script publishes an Image into Shared Image Gallery. An existing Shared Image Gallery with, at least, one Image definition is required.

```powershell
sinequa-for-azure-image-to-gallery.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-imageResourceGroupName] <String>]    
    [[-galleryName] <String>]    
    [[-imageDefinitionName] <String>]    
    [[-imageName] <String>]    
    [[-version] <String>]
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-image-to-gallery.ps1 -version 11.5.1.54 -imageName sinequa-nightly-11.5.1.54 -subscriptionId 00000000-0000-0000-0000-000000000000
```

### 2. Deploy a Sinequa Grid

For deploying a Grid from the Marketplace or from your own image, ARM (Azure Resource Manager) deployment is used.

```powershell
sinequa-for-azure-deploy-grid.ps1
    [[-subscriptionId] <String>]    
    [-templateFile <String>]    
    [-templateParameterFile <SecureString>]    
    [[-resourceGroupName] <String>]    
    [[-galleryName] <String>]    
    [[-imageDefinitionName] <String>]    
    [[-imageName] <String>]    
    [[-version] <String>]
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-deploy-grid.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid
```
This script will run default template:
* mainTemplate.json, ARM template which can instantiate a complete grid with:
  * 1 Application Gateway
  * 1 Availability Set
  * 1 Keyvault
  * 2 Network security group
  * 1 Public IP address (if public)
  * 1 Storage account
  * 2 Virtual machine scale sets
  * 1 Virtual network
  * 1 or 3 Virtual Machines for Primary Nodes
* mainTemplate.parameters.json: paramaters that should be updated

| Parameter              | Description |
| ---------------------- | ----------- |
| license                | Sinequa Licence |
| location               | |
| prefix                 | Prefix of object name. Default: sq |
| adminUsername 	 | Windows User. Default: sinequa |
| adminPassword 	 | Windows User Password |
| vmSize 		 | vmSize of primary nodes. Default: Standard_D4s_v3 |
| vmIndexerSize 	 | vmSize of the indexer Scale Set. Default: Standard_B2s |
| vmIndexerScaleSetSize  | Indexer Scale Set size. Default: 1 |
| vmConnectorSize 	 | vmSize of the connector Scale Set. Default: Standard_B2s |
| vmConnectorScaleSetSize| Connector Scale Set size. Default: 1 |
| primaryNodeCount 	 | Number of primary nodes (1 or 3) |
| virtualNetworkName 	 | Virtual Networdk Name |
| addressPrefixes 	 | Ip Address Range. Default: 10.6.0.0/16 |
| appSubnetName 	 | Subnet App Name for Applications. Default: snet-app |
| frontSubnetName 	 | Subnet App Name for FrontEnd (Application Gateway). Default: snet-front |
| appSubnetPrefix 	 | Ip range for App subnet. Default: 10.6.0.0/24 |
| frontSubnetPrefix 	 | Ip range for Frontend subnet. Default: 10.6.1.0/24 |
| loadBalancerType  	 | Application Gateway is accessible from internet. Possible values are: internal/external |
| certificateBase64 	 | Certificate file (pfx) in base64 format for HTTPS |
| certificatePassword    | Password of the certificate |
| imageReferenceId       | Id of the custom image to use. If empty the marketplace will be used.<br> Example: "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly" |
		
### 3. Add node to a Sinequa Grid
#### 3.1 Add a VM Node  
Add a VM node which is a regular node.

```powershell
sinequa-for-azure-add-vm-node-to-grid.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-resourceGroupName] <String>]    
    [[-imageReferenceId] <String>]    
    [-nodeName <String>]    
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-add-vm-node-to-grid.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -imageReferenceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
```

#### 3.2 Add a VMSS Node  
Add a VM Scale Set node for indexers or connectors.

```powershell
sinequa-for-azure-add-vmss-node-to-grid.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-resourceGroupName] <String>]    
    [[-imageReferenceId] <String>]    
    [-nodeName <String>]    
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-add-vmss-node-to-grid.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -imageReferenceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
```

### 4. Update a Sinequa Grid
#### 3.1 Update a VM Node  
Update a VM node to an another version. This script will create a temporay VM with a new image, and then switch the OS disk of the VM to update

```powershell
sinequa-for-azure-upgrade-vm-node.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-resourceGroupName] <String>]    
    [[-imageReferenceId] <String>]    
    [-nodeName <String>]    
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-upgrade-vm-node.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -imageReferenceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
```

#### 3.2 Update a VMSS Node  
Update a VM Scale Set node for indexers or connectors. This script remove an existing VMSS and recreate it with a new image

```powershell
sinequa-for-azure-upgrade-vmss-node.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-resourceGroupName] <String>]    
    [[-imageReferenceId] <String>]    
    [-nodeName <String>]    
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-upgrade-vmss-node.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -imageReferenceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
```

#### 3.2 Update all nodes  
Update all VM and VMSS of a grid (Resource Group).

```powershell
sinequa-for-azure-upgrade-all-nodes.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-resourceGroupName] <String>]    
    [[-imageReferenceId] <String>]    
    [-nodeName <String>]    
```

Example:
```powershell
PS C:\> .\sinequa-for-azure-upgrade-all-nodes.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -imageReferenceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
```
