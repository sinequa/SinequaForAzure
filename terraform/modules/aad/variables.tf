variable "virtual_machine_id" {
  description       = "Virtual Machine Id"
  type              = string
}
   
variable "is_vm" {
  description       = "Is Virtual Machine or Virtual Machine Scaleset"
  type              = bool
  default           = true
}

variable "local_admins" {
  description = "members of the local administrators group"
  type = list(string)
  default = []
}
