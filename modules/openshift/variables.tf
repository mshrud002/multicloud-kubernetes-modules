variable "cluster_name" {
  description = "Name of the OpenShift cluster"
  type        = string
}

variable "platform" {
  description = "Cloud platform for OpenShift (rosa, aro)"
  type        = string
  default     = "rosa"
}

variable "openshift_version" {
  description = "OpenShift version"
  type        = string
  default     = "4.18"
}

variable "hosted_control_plane" {
  description = "Enable Hosted Control Planes (HyperShift) - separates control plane from data plane"
  type        = bool
  default     = false
}

variable "aws" {
  description = "AWS-specific configuration for ROSA"
  type = object({
    region               = optional(string, "us-east-1")
    vpc_id               = optional(string)
    subnet_ids           = optional(list(string))
    private_subnet_ids   = optional(list(string))
    public_subnet_ids    = optional(list(string))
    machine_cidr         = optional(string, "10.0.0.0/16")
    service_cidr         = optional(string, "172.30.0.0/16")
    pod_cidr             = optional(string, "10.128.0.0/14")
    host_prefix          = optional(number, 23)
    node_disk_size       = optional(number, 120)
    replicas             = optional(number, 3)
    compute_machine_type = optional(string, "m5.xlarge")
  })
  default = {}
}

variable "azure" {
  description = "Azure-specific configuration for ARO"
  type = object({
    location          = optional(string, "eastus")
    resource_group    = optional(string)
    vnet_id           = optional(string)
    subnet_id         = optional(string)
    master_subnet_id  = optional(string)
    worker_subnet_id  = optional(string)
    cluster_rg        = optional(string)
  })
  default = {}
}

variable "machine_pools" {
  description = "Machine pool configuration"
  type = map(object({
    machine_type = string
    replicas     = optional(number, 3)
    min_replicas = optional(number, 3)
    max_replicas = optional(number, 10)
    labels       = optional(map(string), {})
    taints       = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    autoscaling_enabled = optional(bool, true)
  }))
  default = {}
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler for machine pools"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_config" {
  description = "Cluster Autoscaler configuration"
  type = object({
    balance_similar_node_groups        = optional(bool, true)
    skip_nodes_with_local_storage      = optional(bool, false)
    skip_nodes_with_system_pods        = optional(bool, true)
    max_node_provision_time            = optional(string, "15m")
    max_graceful_termination_sec       = optional(number, 600)
    scale_down_delay_after_add         = optional(string, "10m")
    scale_down_delay_after_delete      = optional(string, "10s")
    scale_down_delay_after_failure     = optional(string, "3m")
    scale_down_unneeded_time           = optional(string, "10m")
    scale_down_unready_time            = optional(string, "20m")
  })
  default = {}
}

variable "enable_karpenter" {
  description = "Enable Karpenter for OpenShift (experimental, applies Karpenter Helm chart)"
  type        = bool
  default     = false
}

variable "karpenter_config" {
  description = "Karpenter configuration for OpenShift (experimental)"
  type = object({
    chart_version = optional(string, "1.2.0")
    namespace     = optional(string, "kube-system")
    extra_sets    = optional(map(string), {})
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
