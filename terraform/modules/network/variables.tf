variable "location" {
  description   = "Azure Location"
  type          = string
  default       = "francecentral"
}

variable "resource_group_name" {
  description       = "The name of the resource group"
  type              = string
}

variable "vnet_name" {
  description       = "The name of the vnet"
  type              = string
}

variable "subnet_app_name" {
  description       = "The name of the subnet for the application"
  type              = string
  default           = "snet-app"  
}

variable "subnet_front_name" {
  description       = "The name of the subnet for the frontend (application gateway)"
  type              = string
  default           = "snet-www"  
}

variable "nsg_app_name" {
  description       = "The name of the network security group for the application"
  type              = string
}

variable "nsg_front_name" {
description       = "The name of the network security group for the frontend"
  type              = string
}

variable "require_front_subnet" {
description       = "Allow HTTPS inbound from Internet with an AppGateway"
  type            = bool
  default         = false
}

variable "allow_http_on_app_nsg" {
description       = "Allow HTTP inbound from Internet"
  type            = bool
  default         = false
}

variable "tags" {
  type = map
}
