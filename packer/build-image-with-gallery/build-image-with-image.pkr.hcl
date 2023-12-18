packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    windows-update = {
      version = "0.14.3"
      source = "github.com/rgl/windows-update"
    }
  }
}

variable "tenant_id" {
  description = "Tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID"
  type        = string
}

variable "additional_tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Resource Group"
  type        = string
}

variable "version" {
  description = "Sinequa Version to install"
  type        = string
}

variable "download_token" {
  description = "Build Download Token"
  type        = string
  default     = ""
}

variable "download_url" {
  description = "Build Download Url"
  type        = string
}

variable "vm_size" {
  description = "VM Size"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "gallery_name" {
  description = "Galery Name for publishing the image"
  type        = string
}

variable "gallery_image_name" {
  description = "Image Definition Name in the Galery"
  type        = string
}

variable "gallery_image_version" {
  description = "Image Definition Version in the Galery"
  type        = string
}

variable "gallery_regions" {
  description = "Regions where the image will be replicated"
  type        = list(string)
  default     = ["westeurope"]
}



source "azure-arm" "build-image" {
  tenant_id                         = var.tenant_id
  subscription_id                   = var.subscription_id
  use_azure_cli_auth                = true
  build_resource_group_name         = var.resource_group_name

  os_type                           = "Windows"
  image_offer                       = "WindowsServer"
  image_publisher                   = "MicrosoftWindowsServer"
  image_sku                         = "2022-datacenter-smalldisk"
  vm_size                           = var.vm_size
  os_disk_size_gb                   = 64

  communicator                      = "winrm"
  winrm_insecure                    = true
  winrm_timeout                     = "5m"
  winrm_use_ssl                     = true

  azure_tags                        = var.additional_tags

  managed_image_name                = "sinequa-${var.version}"
  managed_image_resource_group_name = var.resource_group_name

  shared_image_gallery_destination {
    subscription                    = var.subscription_id
    resource_group                  = var.resource_group_name
    gallery_name                    = var.gallery_name
    image_name                      = var.gallery_image_name
    image_version                   = var.gallery_image_version
    replication_regions             = var.gallery_regions
  }
}


build {
  sources = ["source.azure-arm.build-image"]

  provisioner "file" {
    source = "../resources/"
    destination = "d:\\"
  }

  provisioner "powershell" {
    inline = [
      "while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "d:\\sinequa-install-base-programs.ps1"
    ]
  }

  provisioner "windows-update" {
  }

  provisioner "powershell" {
    inline = [
      "d:\\sinequa-install-build.ps1 -downloadUrl \"${var.download_url}\" -downloadToken \"${var.download_token}\"",
      "d:\\sinequa-image-sysprep.ps1"
    ]
  }
}




