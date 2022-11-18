variable "location" {
  description   = "Azure Location"
  type          = string
  default       = "francecentral"
}

variable "api_domain" {
  description   = "API domain suffix for Services"
  type          = string
  default       = "windows.net"
}


variable "resource_group_name" {
  description       = "The name of the resource group"
  type              = string
}

variable "kv_name" {
  description       = "The name of the keyvault"
  type              = string
}

variable "st_premium_name" {
  description       = "The name of the primary storage account"
  type              = string
}

variable "st_hot_name" {
  description       = "The name of the secondary storage account"
  type              = string
}

variable "org_name" {
    description     = "Org Name"
    type            = string
}

variable "grid_name" {
    description     = "Grid Name"
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
    default         = ""
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

variable "blob_sinequa_node_aliases" {
    type            = map
    default         = {}
}
variable "blob_sinequa_version" {
    type            = string
    default         = ""
}

variable "tags" {
  type              = map
  default           = {}
}