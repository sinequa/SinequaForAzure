variable "tenant_id" {
  description = "Tenant ID"
  type        = string
}

variable "sub_www_id" {
  description = "Subscription ID"
  type        = string
}

variable "location" {
  description = "Region"
  type        = string
  default     = "francecentral"
}


variable "repo" {
  description = "Sinequa - Type of build"
  type        = string
  default     = "nighlty"
}

variable "version_number" {
  description = "Sinequa - Full version number"
  type        = string
}
