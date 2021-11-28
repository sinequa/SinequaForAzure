variable "location" {
  description   = "Azure Location"
  type          = string
  default       = "francecentral"
}

variable "resource_group_name" {
  description       = "The name of the resource group"
  type              = string
}

variable "availability_set_name" {
  description       = "The name of the availability set"
  type              = string
}

variable "application_gateway_name" {
  description       = "The name of the application gateway"
  type              = string
}

variable "subnet_id" {
  description       = "The  subnet id for the frontend"
  type              = string
}

variable "certificate" {
  description       = "SSL certificate"
  type              = map
}

variable "dns_name" {
  description       = "Azure DNS name for Application Gateway"
  type              = string
  default           = null
}

variable "kv_identity_reader" {
  description       = "Identity used for reading the SSL certificate stored in a KV"
  type = object({
    identity_ids    = list(string)
  })
  default           = null
}   

variable "tags" {
  type = map
}