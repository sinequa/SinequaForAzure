variable "tenant_id" {
  description = "Tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID"
  type        = string
}

variable "location" {
  description = "Region"
  type        = string
  default     = "francecentral"
}

variable "azure_environment" {
  description = "Azure Environment" // https://learn.microsoft.com/en-us/powershell/module/az.accounts/get-azenvironment 
  type        = string
  default     = "AzureCloud" 
}

variable "dev_image_id" {
  description = "Sinequa Image reference for DEV grid"
  type        = string
}

variable "prd_image_id" {
  description = "Sinequa Image reference for PROD grid"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group"
  type        = string
}

variable "additional_tags" {
  description = "Tags for all resources"
  type        = map
  default     = {}
}
