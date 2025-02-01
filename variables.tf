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

variable "vm_count" {
  description = "Number of session host VMs"
  default     = 2
}


variable "allowed_rdp_ips" {
  description = "List of public IPs allowed to access RDP (3389)."
  type        = list(string)
  default     = [] # Can be set here or in terraform.tfvars
}


variable "admin_password" {
  description = "Initial admin password for AVD session hosts"
  type        = string
  sensitive   = true
}
variable "admin_username" {
  description = "Initial admin username for AVD session hosts"
  type        = string
  sensitive   = true
}

variable "vm_names" {
  type = map(string)
  default = {
    "vm1" = "avd-vm-1"
    "vm2" = "avd-vm-2"
  }
}
