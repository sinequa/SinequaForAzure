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

variable "license" {
    type            = string
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

variable "tags" {
  type              = map
  default           = {}
}