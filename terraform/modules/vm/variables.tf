variable "location" {
  description   = "Azure Location"
  type          = string
  default       = "francecentral"
}

variable "resource_group_name" {
  description       = "The name of the resource group"
  type              = string
}

variable "vm_name" {
  description       = "The name of the vm"
  type              = string
}

variable "vm_size" {
  description       = "Azure VM size"
  type              = string
  default           = "Standard_E8s_v3"
}

variable "computer_name" {
    type            = string
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
    default         = "Premium_LRS"
}

variable "data_disk_type" {
    type            = string
    default         = "Premium_LRS"
}

variable "data_disk_size" {
    type            = number
    default         = 100
}

variable "admin_username" {    
    type            = string
    default         = "sinequa"
}

variable "admin_password" {
    type            = string
}

variable "key_vault_id" {
    type            = string
    default         = ""
}

variable "storage_account_id" {
    type            = string
    default         = ""
}

variable "availability_set_id" {
    type            = string
    default         = ""
}

variable "pip" {
    default         = false
}

variable "backend_address_pool_id" {
    type            = string
}

variable "network_security_group_id" {
    type            = string
}

variable "datadisk_ids" {
    description     = "Provide specifics datadisks (replace default one)"
    type            = list(string)  
    default         = []
}

variable "tags" {
  type = map
}