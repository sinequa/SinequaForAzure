# Packer 

Sinequa For Azure (S4A) Packer is a set of Packer scripts used for building a Sinequa ES image.

#### Table of Contents
0. [Prerequisites](#prerequisites)<br>
1. [build-image Sample](#build-image)<br>
2. [build-image-with-image Sample](#build-image-with-image)<br>
3. [Resources used by Packer provisioners](#resources)<br>

  
## Scripts

### 0. Prerequisites <a name="prerequisites">

* Install Packer: https://developer.hashicorp.com/packer/install?product_intent=packer
* Access to https://portal.azure.com
* Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

### 1. build-image Sample <a name="build-image">

`build-image\build-image.pkr.hcl`: Create a VM image with packer
 
 Example:

```powershell
 > .\packer.exe init -upgrade build-image.pkr.hcl
 > .\packer.exe build `
  -var "tenant_id=xxxxxx" `
  -var "subscription_id=xxxxxx" `
  -var "client_id=xxxxxx" `
  -var "client_secret=xxxxxx" `
  -var "resource_group_name=packer-resource-group" `
  -var "image_name=sinequa-11.10.0.2098" `
  -var "download_url=https://download.sinequa.com/api/filedownload?type=release&version=11.10.0.2098&file=sinequa.11.zip" `
  -var "downloadToken=xxxxxx" `
  -var "vm_size=Standard_NV6ads_a10_v5" `
  build-image.pkr.hcl
```

### 2. build-image-with-image Sample <a name="build-image-with-image">
`build-image-with-image\build-image-with-image.pkr.hcl`: Create a VM image with packer and publish it in an Image Gallery
 
 Example:

```powershell
 > .\packer.exe init -upgrade build-image-with-image.pkr.hcl
 > .\packer.exe build `
  -var "tenant_id=xxxxxx" `
  -var "subscription_id=xxxxxx" `
  -var "client_id=xxxxxx" `
  -var "client_secret=xxxxxx" `
  -var "resource_group_name=packer-resource-group" `
  -var "image_name=sinequa-11.10.0.2098" `
  -var "download_url=https://download.sinequa.com/api/filedownload?type=release&version=11.10.0.2098&file=sinequa.11.zip" `
  -var "downloadToken=xxxxxx" `
  -var "vm_size=Standard_NV6ads_a10_v5" `
  -var "gallery_name=Sinequa" `
  -var "gallery_image_name=Release" `
  -var "gallery_image_version=11.10.0" `  
  build-image-with-image.pkr.hcl
```
### 3. Resources used by Packer provisioners <a name="resources">

In the resource folder, scripts are provided to be used in the VM for building the image:

* **sinequa-install-base-programs.ps1**: Install prerequistes and GPU driver 

Command line:

> .\sinequa-install-base-programs.ps1

Note: For installing the Nvidia driver, the VM used for the creation of the image, must have GPU, otherwise the installer will skip it.

* **sinequa-install-build.ps1**: Deploys a key vault and a storage account.

Command line:

> .\sinequa-install-build.ps1 -downloadUrl \<URL of sinequa.zip\> -downloadToken \<Token for the URL\>

Parameter | Description
--- | --- 
downloadUrl | URL of sinequa.zip
downloadToken | Optional. Token that is used as a Bearer token, in the Authorization HTTP Header of the `downloadUrl`

Sample with the Sinequa Download Center

> .\sinequa-install-build.ps1 -downloadUrl "https://download.sinequa.com/api/filedownload?type=release&version=11.10.0.2098&file=sinequa.11.zip" -downloadToken "xxxxxxxx"

* **sinequa-image-sysprep.ps1**: Generalizing the image and removes computer-specific information.

Command line:

> .\sinequa-image-sysprep.ps1