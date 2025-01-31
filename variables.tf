variable "resource_group_name" {}
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "germanywestcentral"
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
