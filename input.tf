variable "base_name" {
  description = "Base name to name all resources"
  type = string
  default = "test-foundryvtt"
}

variable "location" {
  description = "Az region to put the resources into"
  type = string
  default = "France Central"
}

variable "foundry_username" {
  description = "Login for the foundry website. Used to retrieve the last build version"
  type        = string
  sensitive   = true
}

variable "foundry_password" {
  description = "Password for the foundry website. Used to retrieve the last build version"
  type        = string
  sensitive   = true
}

variable "foundry_hostname" {
  description = "Real hostname for the foundry website"
  type        = string
  sensitive   = true
}

variable "foundry_admin_password" {
  description = "Password to access the admin interface of the foundry instance"
  type        = string
  sensitive   = true
}