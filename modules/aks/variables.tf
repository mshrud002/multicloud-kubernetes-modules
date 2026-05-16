variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.31"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the cluster"
  type        = string
}

variable "vnet_subnet_id" {
  description = "ID of the subnet for the AKS cluster"
  type        = string
}

variable "enable_automatic_mode" {
  description = "Enable AKS Automatic mode (automated cluster operations and scaling)"
  type        = bool
  default     = false
}

variable "enable_node_auto_provisioning" {
  description = "Enable Node Auto Provisioning (NAP) for dynamic node pool creation"
  type        = bool
  default     = false
}

variable "automatic_sku" {
  description = "SKU tier for AKS Automatic mode"
  type        = string
  default     = "Automatic"
}

variable "node_pools" {
  description = "Node pools configuration (used when automatic_mode and NAP are disabled)"
  type = map(object({
    vm_size            = string
    desired_count      = optional(number, 2)
    min_count          = optional(number, 1)
    max_count          = optional(number, 10)
    os_disk_size_gb    = optional(number, 128)
    labels             = optional(map(string), {})
    taints             = optional(list(string), [])
    enable_auto_scaling = optional(bool, true)
    availability_zones = optional(list(string), ["1", "2", "3"])
  }))
  default = {}
}

variable "network_profile" {
  description = "Network profile configuration"
  type = object({
    network_plugin      = optional(string, "azure")
    network_policy      = optional(string, "calico")
    load_balancer_sku   = optional(string, "standard")
    outbound_type       = optional(string, "loadBalancer")
  })
  default = {}
}

variable "identity_type" {
  description = "Type of managed identity to use"
  type        = string
  default     = "SystemAssigned"
}

variable "enable_karpenter" {
  description = "Enable Karpenter for AKS (experimental)"
  type        = bool
  default     = false
}

variable "karpenter_config" {
  description = "Karpenter configuration for AKS (experimental)"
  type = object({
    chart_version      = optional(string, "1.2.0")
    identity_client_id = optional(string)
    node_resource_group = optional(string)
    extra_sets         = optional(map(string), {})
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
