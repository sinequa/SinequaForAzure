variable "storage_account_name" {
  description       = "The name of the primary storage account"
  type              = string
}

variable "org_name" {
    description     = "Org Name"
    type            = string
}

variable "grid_name" {
    description     = "Grid Name"
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

variable "blob_sinequa_authentication_enabled" {
    type            = bool
    default         = false
}

variable "blob_sinequa_node_aliases" {
    type            = map
    default         = {}
}

variable "blob_sinequa_nodelist_aliases" {
    type            = map
    default         = {}
}

variable "blob_sinequa_engine_aliases" {
    type            = map
    default         = {}
}

variable "blob_sinequa_enginelist_aliases" {
    type            = map
    default         = {}
}

variable "blob_sinequa_indexer_aliases" {
    type            = map
    default         = {}
}

variable "blob_sinequa_indexerlist_aliases" {
    type            = map
    default         = {}
}

variable "blob_sinequa_version" {
    type            = string
    default         = ""
}
