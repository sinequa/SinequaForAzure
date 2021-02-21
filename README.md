# SinequaForAzure

Sinequa For Azure (S4A) is a set of Azure optimizations for reducing cost and improving reliability and performances

#### Table of contents
1. [Create Your Own Sinequa Image](#ownimage)<br>
   1.1. [Create the Base Image](#ownimage_base)<br>
   1.2. [Create a Sinequa Version Image](#ownimage_version)<br>
   1.3. [Publish an Image in a Shared Image Gallery (Optional)](#ownimage_shared)<br>
2. [Deploy a Sinequa Grid](#deploy)<br>
3. [Add node to a Sinequa Grid](#add)<br>
   3.1. [Add a VM Node](#add_vm)<br>
   3.2. [Add a VMSS Node](#add_vmss)<br>
4. [Update a Sinequa Grid](#update)<br> 
   4.1. [Update a VM Node](#update_vm)<br>
   4.2. [Update a VM Node](#update_vmss)<br>
   4.3. [Update All Nodes](#update_all)<br>

In the script folder, different PowerShell scripts allow you to deploy and manage a Sinequa Grid based on the Official Sinequa Marketplace Image or by your own Sinequa Custom Image

Depending on where are located Sinequa Images and where you deploy a Grid, different sources can be used:
- Deploy a Grid in an **another Tenant** than your image: **Only Marketplace** can be used (Official Image, not a custom image)
- Deploy a Grid in the **same Tenant** but not in the same subscription: **Marketplace** or **Shared Image Gallery** 
- Deploy a Grid in the **same subscription**: **Marketplace** or **Shared Image Gallery** or **Image**

## Prerequisites
In PowerShell run these commands:
```powershell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Az -AllowClobber -Force
Connect-AzAccount
```

## Scripts
### 1. Create Your Own Sinequa Image <a name="ownimage">

#### 1.1. Create the Base Image <a name="ownimage_base">
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
# Create 'sinequa-base-image' in the 'MyImage' resource group (sub-snqa-sandbox subscription)
PS C:\> .\sinequa-for-azure-build-base-image.ps1 -subscriptionId 8a9fc7e2-ac08-4009-8498-2026cb37bb25 -imageResourceGroupName MyImages -imageName sinequa-base-image
```

This script will run these "Custom Sript Extensions":
* sinequa-az-cse-install-programs.ps1, that could be customized for adding programms
	ex
```powershell
# Google Chrome
Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile "$tempDrive\chrome_installer.exe"
Start-Process -FilePath "chrome_installer.exe" -Args "/silent /install" -Verb RunAs -Wait

# NotePadd++
Invoke-WebRequest "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v7.9/npp.7.9.Installer.exe" -OutFile "$tempDrive\npp.7.9.Installer.exe"
Start-Process -FilePath "npp.7.9.Installer.exe" -Args "/S" -Wait -PassThru

#Visual Code
Invoke-WebRequest "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" -OutFile "$tempDrive\VSCodeSetup.exe"
Start-Process -FilePath "VSCodeSetup.exe" -Args "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait -PassThru

```	
* sinequa-az-cse-windows-update.ps1: Apply Windows Updates

#### 1.2. Create a Sinequa Version Image <a name="ownimage_version">
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
# Create 'sinequa-nightly-11.5.1.54' in the 'MyImage' resource group (sub-snqa-sandbox subscription) from the 'sinequa-base-image' base image with a local zip file
PS C:\> .\sinequa-for-azure-build-image.ps1 -subscriptionId 8a9fc7e2-ac08-4009-8498-2026cb37bb25 -baseImageName sinequa-base-image -version 11.5.1.54 -imageName sinequa-nightly-11.5.1.54 -imageResourceGroupName MyImages -localfile c:\builds\11.5.1.54\sinequa.11.zip
```

#### 1.3. Publish an Image in a Shared Image Gallery (Optional) <a name="ownimage_shared">
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
# Publish the 'sinequa-nightly-11.5.1.54' into the 'MySinequaForAzure' Shared Image Gallery ('MySinequaNightly' Image Definition)
PS C:\> .\sinequa-for-azure-image-to-gallery.ps1 -subscriptionId 8a9fc7e2-ac08-4009-8498-2026cb37bb25 -imageName sinequa-nightly-11.5.1.54 -version 11.5.1.54 -galleryName MySinequaForAzure -imageDefinitionName MySinequaNightly
```

### 2. Deploy a Sinequa Grid <a name="deploy">

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
# Deply a complete grid in the 'MySQGrid' resource group
PS C:\> .\sinequa-for-azure-deploy-grid.ps1 -subscriptionId 8a9fc7e2-ac08-4009-8498-2026cb37bb25 -resourceGroupName MySQGrid
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
		
### 3. Add node to a Sinequa Grid <a name="add">	
#### 3.1. Add a VM Node <a name="add_vm"> 
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
# Adds a VM node in the 'MySQGrid' resource group
PS C:\> .\sinequa-for-azure-add-vm-node-to-grid.ps1 -subscriptionId 8a9fc7e2-ac08-4009-8498-2026cb37bb25 -resourceGroupName MySQGrid -imageReferenceId "/subscriptions/8a9fc7e2-ac08-4009-8498-2026cb37bb25/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/MySinequaForAzure/images/MySinequaNightly"
```

#### 3.2. Add a VMSS Node <a name="add_vmss"> 
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
# Adds a VMSS node in the 'MySQGrid' resource group
PS C:\> .\sinequa-for-azure-add-vmss-node-to-grid.ps1  -subscriptionId 8a9fc7e2-ac08-4009-8498-2026cb37bb25 -resourceGroupName MySQGrid -imageReferenceId "/subscriptions/8a9fc7e2-ac08-4009-8498-2026cb37bb25/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/MySinequaForAzure/images/MySinequaNightly"
```

### 4. Update a Sinequa Grid <a name="update"> 
#### 4.1. Update a VM Node <a name="update_vm">   
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
    [[-vmName] <String>]    
```

Example:
```powershell
# Update the "vm-sq-7" VM of the 'MySQGrid' resource group with the latest version of 'MySinequaNightly'
PS C:\> .\sinequa-for-azure-upgrade-vm-node.ps1 -subscriptionId 8a9fc7e2-ac08-4009-8498-2026cb37bb25 -resourceGroupName MySQGrid -imageReferenceId "/subscriptions/8a9fc7e2-ac08-4009-8498-2026cb37bb25/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/MySinequaForAzure/images/MySinequaNightly" -vmName vm-sq-7
```

#### 4.2. Update a VMSS Node <a name="update_vmss">    
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
    [-vmssName <String>]    
```

Example:
```powershell
# Update the "vmss-sq-indexer" VMSS of the 'MySQGrid' resource group with the latest version of 'MySinequaNightly'
PS C:\> .\sinequa-for-azure-upgrade-vmss-node.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -imageReferenceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly" -vmssName vmss-sq-connector
```

#### 4.3. Update All Nodes <a name="update_all">    
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
```

Example:
```powershell
# Update all VM and VMSS of the 'MySQGrid' resource group with the latest version of 'MySinequaNightly'
PS C:\> .\sinequa-for-azure-upgrade-all-nodes.ps1 -subscriptionId 00000000-0000-0000-0000-000000000000 -resourceGroupName sq-grid -imageReferenceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Sinequa/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
```
