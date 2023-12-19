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

variable "client_id" {
  description = "Client ID"
  type        = string
}

variable "client_secret" {
  description = "Client Secret"
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

variable "image_name" {
  description = "Image name to build"
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

source "azure-arm" "build-image" {
  tenant_id                         = var.tenant_id
  subscription_id                   = var.subscription_id
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  #use_azure_cli_auth                = true

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

  managed_image_name                = var.image_name
  managed_image_resource_group_name = var.resource_group_name
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




