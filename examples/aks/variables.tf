variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Existing resource group name (optional)"
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "enable_automatic_mode" {
  description = "Enable AKS Automatic mode"
  type        = bool
  default     = false
}

variable "enable_node_auto_provisioning" {
  description = "Enable Node Auto Provisioning"
  type        = bool
  default     = false
}

variable "node_pools" {
  description = "Node pools (used when automatic and NAP are disabled)"
  type = map(object({
    vm_size       = string
    desired_count = optional(number, 2)
    min_count     = optional(number, 1)
    max_count     = optional(number, 10)
    labels        = optional(map(string), {})
    taints        = optional(list(string), [])
  }))
  default = {}
}

variable "enable_karpenter" {
  description = "Enable Karpenter for AKS (experimental)"
  type        = bool
  default     = false
}

variable "karpenter_config" {
  description = "Karpenter configuration for AKS"
  type = any
  default = null
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
