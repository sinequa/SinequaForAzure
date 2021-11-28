variable "location" {
  description   = "Azure Location"
  type          = string
  default       = "francecentral"
}

variable "resource_group_name" {
  description       = "The name of the resource group"
  type              = string
}

variable "kv_name" {
  description       = "The name of the keyvault"
  type              = string
}

variable "st_name" {
  description       = "The name of the storage account"
  type              = string
}

variable "container_name" {
  description       = "The name of the blob container"
  type              = string
}

variable "data_storage_root" {
    description     = "Root folder after the container name"
    type            = string
    default         = "" 
}

variable "license" {
    type            = string
}

variable "admin_password" {
    type            = string
    default         = ""
}

variable "default_admin_password" {
    type            = string
    default         = ""
}

variable "blob_sinequa_primary_nodes" {
    type            = string
}

variable "blob_sinequa_beta" {
    default         = false
}

variable "blob_sinequa_keyvault" {
    type            = string
}

variable "blob_sinequa_queuecluster" {
    type            = string
    default         = ""
}

variable "blob_sinequa_authentication_secret" {
    type            = string
    default         = ""
}

variable "blob_sinequa_authentication_enabled" {
    type            = bool
    default         = false
}

variable "blob_sinequa_version" {
    type            = string
    default         = ""
}

variable "tags" {
  type              = map
  default           = {}
}