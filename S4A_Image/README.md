# S4A_Image

Sinequa For Azure (S4A) Image is a set of scripts for creating your own Sinequa Image on Azure

#### Table of contents
1. [Create the Base Image](#ownimage_base)<br>
2. [Create a Sinequa Version Image](#ownimage_version)<br>
3. [Publish an Image in a Shared Image Gallery (Optional)](#ownimage_shared)<br>

In the script folder, different PowerShell scripts allow you to create your own Sinequa Azure Image that you can deploy for creating a Sinequa Grid

Depending on where are located Sinequa Images and where you deploy a Grid, different sources can be used:
- Deploy a Grid in an **another Tenant** than your image: **Only the Azure Marketplace** can be used (Official Image, not a custom image)
- Deploy a Grid in the **same Tenant** but not in the same subscription: **Marketplace** or your own **Shared Image Gallery** 
- Deploy a Grid in the **same subscription**: **Marketplace** or your own **Shared Image Gallery** or your own **Image**

## Diagram

![Sinequa For Azure Scripts](images/S4A_Image.png)

## Scripts

#### 1. Create the Base Image <a name="ownimage_base">
This first image is a **Windows Base Image** (Microsoft Windows 2019 Datacenter) including **all Sinequa pre-requisites** and **additional programs** that you want to install before building a specific version of Sinequa.

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
| Parameter              | Default Value                   | Description |
| ---------------------- | ------------------------------- | ----------- |
| tenantId               | $env:AZURE_PRODUCT_TENANT       | Tenant ID used for login |
| subscriptionId         | $env:AZURE_PRODUCT_SUBSCRIPTION | Subscription ID used for login |
| user 	                 | $env:AZURE_BUILD_USER           | User for login |
| password 	             | $env:AZURE_BUILD_PWD            | Password for login |
| location               | francecentral                   | Azure Region |
| imageResourceGroupName | rg-sinequa                      | Resource Group Name the base image to create |
| imageName              | sinequa-base-image              | Name of the image containing the pre-requisites and additional programs |
| tempResourceGroupName  | temp-sinequa-base-image         | Transient resource group for building a VM to generalyzed |
| osUsername             | sinequa                         | OS user for the transient VM |
| osPassword             | Password1234                    | OS password for the transient VM |

Example:
```powershell
PS C:\> .\sinequa-for-azure-build-base-image.ps1 -tenantId 00000000-0000-0000-0000-000000000000 -subscriptionId 00000000-0000-0000-0000-000000000000
```

This script will run these "Custom Sript Extensions":
* `sinequa-az-cse-install-programs.ps1` for installing Sinequa pre-requisites and optional programs. This script could be customized.
    * Install a Custom BGInfo that displays the Sinequa ES version
    * Install C++ Resdistribuable
    * Install 7zip
    * Install Google Chrome
    * Install NotePad++
    * Install Visual Code
    * Install GIT client
* `sinequa-az-cse-windows-update.ps1`: Apply Windows Updates

#### 2. Create a Sinequa Version Image <a name="ownimage_version">
Create an **Sinequa Image** from a **distribution file** (sinequa.11.zip). This script will install Sinequa (Unzip & Install Services) that can be specialized (Engine, Indexer, .. roles) during the first init (Deployment).
* `localFile` or `fileUrl` has to be set

```powershell
sinequa-for-azure-build-image.ps1
    [[-tenantId] <String>]    
    [[-subscriptionId] <String>]    
    [-user <String>]    
    [-password <SecureString>]    
    [[-location] <String>]    
    [[-imageResourceGroupName] <String>]    
    [[-baseImageName] <String>]    
    [-imageName <String>]    
    [-version <String>]
    [[-tempResourceGroupName] <String>]    
    [[-localFile] <String>]
    [[-fileUrl] <String>]
    [[-osUsername] <String>]    
    [[-osPassword] <Securetring>]       
```

| Parameter              | Default Value                   | Description |
| ---------------------- | ------------------------------- | ----------- |
| tenantId               | $env:AZURE_PRODUCT_TENANT       | Tenant ID used for login |
| subscriptionId         | $env:AZURE_PRODUCT_SUBSCRIPTION | Subscription ID used for login |
| user 	                 | $env:AZURE_BUILD_USER           | User for login |
| password 	             | $env:AZURE_BUILD_PWD            | Password for login |
| location               | francecentral                   | Azure Region |
| imageResourceGroupName | rg-sinequa                      | Resource Group Name of the base Image and of the new image to create |
| baseImageName          | sinequa-base-image              | Name of the image containing the pre-requisites and additional programs |
| imageName 	         |                                 | Name of the image to create. Eg: sinequa-nightly-11.7.0.0 |
| version 	             |                                 | Version of Sinequa. Eg: 11.7.0.0 |
| localFile 	         |                                 | Local distribution file to use. Eg: c:\install\sinequa.11.zip |
| fileUrl 	             |                                 | Url of the distribution file to use: Eg: https://constoso.com/sinequa.11.zip |
| tempResourceGroupName  | temp-sinequa-image              | Transient resource group for building a VM to generalyzed |
| osUsername             | sinequa                         | OS user for the transient VM |
| osPassword             | Password1234                    | OS password for the transient VM |

Example:
```powershell
PS C:\> .\sinequa-for-azure-build-image.ps1 -version 11.5.1.54 -tempResourceGroupName temp-sinequa-image-11.5.1.54 -imageName sinequa-nightly-11.5.1.54 -localfile c:\builds\11.5.1.54\sinequa.11.zip -tenantId 00000000-0000-0000-0000-000000000000 -subscriptionId 00000000-0000-0000-0000-000000000000
```


#### 3. Publish an Image into a Shared Image Gallery (Optional) <a name="ownimage_shared">
This script publishes an **Image** into an existing **Shared Image Gallery**. An existing Shared Image Gallery with, at least, one Image definition is required.

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
    [-imageName <String>]    
    [-version <String>]
    [[-deleteOlds] <Boolean>]
```

| Parameter              | Default Value                   | Description |
| ---------------------- | ------------------------------- | ----------- |
| tenantId               | $env:AZURE_PRODUCT_TENANT       | Tenant ID used for login |
| subscriptionId         | $env:AZURE_PRODUCT_SUBSCRIPTION | Subscription ID used for login |
| user 	                 | $env:AZURE_BUILD_USER           | User for login |
| password 	             | $env:AZURE_BUILD_PWD            | Password for login |
| location               | francecentral                   | Azure Region |
| imageResourceGroupName | rg-sinequa                      | Resource Group Name of the Image to Share & the Shared Image Gallery|
| galleryName            | SinequaForAzure                 | Shared Image Gallery Name |
| imageDefinitionName 	 | sinequa-11-nightly              | Image Definition Name |
| imageName              |                                 | Image Name to share. Eg: sinequa-release-11.7.0.0 |
| version 	             |                                 | Version of Sinequa. Eg: 11.7.0.0 |
| deleteOlds             | false                           | Keeps only last 5 images |

Example:
```powershell
PS C:\> .\sinequa-for-azure-image-to-gallery.ps1 -version 11.5.1.54 -imageName sinequa-nightly-11.5.1.54 -tenantId 00000000-0000-0000-0000-000000000000 -subscriptionId 00000000-0000-0000-0000-000000000000
```

