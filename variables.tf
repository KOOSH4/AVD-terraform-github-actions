variable "resource_group_name" {}
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "germanywestcentral"
}
variable "location2" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "host_pool_type" {
  description = "AVD host pool type (Pooled/Personal)"
  type        = string
  default     = "Pooled"
}

variable "load_balancer_type" {
  description = "Load balancing algorithm for the host pool"
  type        = string
  default     = "DepthFirst" # Options: 'DepthFirst', 'BreadthFirst'
}
variable "vm_size" {
  description = "VM size for session hosts (e.g., Standard_D2s_v3)"
  type        = string
  default     = "Standard_D2s_v3" # suitable for office workloads
}

variable "admin_username" {
  description = "Admin username for AVD session host VMs"
  type        = string
}

variable "admin_password" {
  description = "Admin password for AVD session host VMs"
  type        = string
  sensitive   = true
}

variable "allowed_rdp_ips" {
  description = "List of public IPs allowed to access RDP (3389)."
  type        = list(string)
  default     = []  # Can be set here or in terraform.tfvars
}
