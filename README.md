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

