variable "location" {
  description   = "Azure Location"
  type          = string
  default       = "francecentral"
}

variable "resource_group_name" {
  description       = "The name of the resource group"
  type              = string
}

variable "vmss_name" {
  description       = "The name of the vmss"
  type              = string
}

variable "vmss_size" {
  description       = "Azure VMSS size"
  type              = string
  default           = "Standard_B2s"
}

variable "vmss_capacity" {
  description       = "Azure VMSS capacity"
  type              = number
  default           = 1
}

variable "subnet_id" {
  description       = "Subnet Id of the vm"
  type              = string
}

variable "image_id" {
  description       = "Image Version Shared Gallery Id"
  type              = string
  default           = "/subscriptions/e88f44fe-533b-4811-a972-5f6a692b0730/resourceGroups/Product/providers/Microsoft.Compute/galleries/SinequaForAzure/images/sinequa-11-nightly"
}

variable "os_disk_type" {
    type            = string
    default         = "Standard_LRS"
}

variable "os_disk_size" {
    type            = number
    default         = 64
}

variable "computer_name_prefix" {
    type            = string
}

variable "admin_username" {    
    type            = string
    default         = "sinequa"
}

variable "admin_password" {
    type            = string
}

variable "network_security_group_id" {
    type            = string
}

variable "user_identity_id" {
    type            = string
}

variable "user_identity_principal_id" {
    type            = string
}

variable "tags" {
  type = map
}