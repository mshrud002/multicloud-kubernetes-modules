variable "cluster_name" {
  description = "Name of the OpenShift cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "openshift_version" {
  description = "OpenShift version"
  type        = string
  default     = "4.18"
}

variable "hosted_control_plane" {
  description = "Enable Hosted Control Planes (HyperShift)"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_config" {
  description = "Cluster Autoscaler configuration"
  type = object({
    balance_similar_node_groups    = optional(bool, true)
    skip_nodes_with_local_storage  = optional(bool, false)
    skip_nodes_with_system_pods    = optional(bool, true)
    max_node_provision_time        = optional(string, "15m")
    scale_down_delay_after_add     = optional(string, "10m")
    scale_down_delay_after_delete  = optional(string, "10s")
    scale_down_delay_after_failure = optional(string, "3m")
    scale_down_unneeded_time       = optional(string, "10m")
    scale_down_unready_time        = optional(string, "20m")
  })
  default = {}
}

variable "machine_pools" {
  description = "Machine pool configuration"
  type = map(object({
    machine_type       = string
    replicas           = optional(number, 3)
    min_replicas       = optional(number, 3)
    max_replicas       = optional(number, 10)
    labels             = optional(map(string), {})
    taints             = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    autoscaling_enabled = optional(bool, true)
  }))
  default = {}
}

variable "enable_karpenter" {
  description = "Enable Karpenter for OpenShift (experimental)"
  type        = bool
  default     = false
}

variable "karpenter_config" {
  description = "Karpenter configuration for OpenShift"
  type = any
  default = null
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
