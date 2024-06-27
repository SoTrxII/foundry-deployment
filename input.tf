variable "base_name" {
  description = "Base name to name all resources"
  type        = string
  default     = "foundryvtt-prod"
}

variable "location" {
  description = "Az region to put the resources into"
  type        = string
  default     = "France Central"
}

variable "min_replicas" {
  description = "Minimum replication of the foundry VTT app"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum replication of the foundry VTT app"
  type        = number
  default     = 1
}

variable "cpu_per_replica" {
  description = "Number of vCPU for each replication of the foundry app"
  type        = number
  default     = 4
}

variable "ram_per_replica" {
  description = "Amount of RAM in GiB for each replication of the foundry app"
  type        = string
  default     = "8Gi"
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
