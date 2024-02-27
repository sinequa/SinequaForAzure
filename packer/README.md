# Packer 

Sinequa For Azure (S4A) Packer is a set of Packer scripts used for building a Sinequa ES image.

#### Table of Contents
0. [Prerequisites](#prerequisites)<br>
1. [build-image Sample](#build-image)<br>
2. [build-image-with-image Sample](#build-image-with-image)<br>
3. [Resources Used by Packer Provisioners](#resources)<br>

  
## Scripts

### 0. Prerequisites <a name="prerequisites">

* Install Packer: https://developer.hashicorp.com/packer/install?product_intent=packer
* Access to https://portal.azure.com
* Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

### 1. build-image Sample <a name="build-image">

`build-image\build-image.pkr.hcl`: Create a VM image with Packer
 
Variable | Description
--- | --- 
tenant_id | Tenant ID
subscription_id | Subscription ID
client_id | Client ID for authentication
client_secret | Client Secret for authentication
resource_group_name | Resource group for creating the image.
image_name | Name of the image. Eg. `sinequa-11.10.0.2098`
download_url | Url of sinequa.zip that will be downloaded from the VM. Eg. `https://download.sinequa.com/api/filedownload?type=release&version=11.10.0.2098&file=sinequa.11.zip`
download_token | Token that is used as a Bearer token in the Authorization HTTP Header of the `download_url`
vm_size | VM size used for building the image. Default is `Standard_D4s_v3`. For installing GPU Driver (for Neural Search), a VM size with GPU must be used.


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
  -var "download_token=xxxxxx" `
  -var "vm_size=Standard_NV6ads_a10_v5" `
  build-image.pkr.hcl
```

### 2. build-image-with-gallery Sample <a name="build-image-with-image">
`build-image-with-gallery\build-image-with-gallery.pkr.hcl`: Create a VM image with Packer and publish into an Image Gallery
 
 Variable | Description
--- | --- 
tenant_id | Tenant ID
subscription_id | Subscription ID
client_id | Client ID for authentication
client_secret | Client Secret for authentication
resource_group_name | Resource group for creating the image.
image_name | Name of the image. Eg. `sinequa-11.10.0.2098`
download_url | Url of sinequa.zip that will be downloaded from the VM. Eg. `https://download.sinequa.com/api/filedownload?type=release&version=11.10.0.2098&file=sinequa.11.zip`
download_token | Token that is used as a Bearer token in the Authorization HTTP Header of the `download_url`
vm_size | VM size used for building the image. Default is `Standard_D4s_v3`. For installing GPU Driver (for Neural Search), a VM size with GPU must be used.
gallery_name | Image Gallery name
gallery_image_name | Image Definition name
gallery_image_version | Image Version
gallery_regions | Regions of the image. Default is `westeurope`

 Example:

```powershell
 > .\packer.exe init -upgrade build-image-with-gallery.pkr.hcl
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
### 3. Resources Used by Packer Provisioners <a name="resources">

In the resource folder, scripts are provided to be used in the VM for building the image:

* **sinequa-install-base-programs.ps1**: Install prerequistes and GPU driver 

Command line:

> .\sinequa-install-base-programs.ps1

Note: For installing the Nvidia driver, the VM used for the creation of the image, must have GPU, otherwise the installer will skip it.

* **sinequa-install-build.ps1**: Install Sinequa.

Command line:

> .\sinequa-install-build.ps1 -downloadUrl \<URL of sinequa.zip\> -downloadToken \<Token for the URL\>

Parameter | Description
--- | --- 
downloadUrl | URL of sinequa.zip
downloadToken | Optional. Token that is used as a Bearer token in the Authorization HTTP Header of the `downloadUrl`

Sample with the Sinequa Download Center

> .\sinequa-install-build.ps1 -downloadUrl "https://download.sinequa.com/api/filedownload?type=release&version=11.10.0.2098&file=sinequa.11.zip" -downloadToken "xxxxxxxx"

* **sinequa-image-sysprep.ps1**: Generalizing the image and removes computer-specific information.

Command line:

> .\sinequa-image-sysprep.ps1