variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "zones" {
  description = "GCP zones for the cluster"
  type        = list(string)
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version for the GKE cluster"
  type        = string
  default     = "1.31"
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot mode (Google-managed nodes and infra)"
  type        = bool
  default     = true
}

variable "network" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Subnetwork name"
  type        = string
  default     = "default"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the control plane"
  type        = string
  default     = "172.16.0.0/28"
}

variable "cluster_resource_labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

variable "release_channel" {
  description = "Release channel for GKE (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    start_time = optional(string, "03:00")
    recurring  = optional(string, "FRI:MON")
  })
  default = {}
}

variable "node_pools" {
  description = "Node pools configuration (only used when autopilot is disabled)"
  type = map(object({
    machine_type       = optional(string, "e2-medium")
    min_count          = optional(number, 1)
    max_count          = optional(number, 10)
    initial_node_count = optional(number, 2)
    disk_size_gb       = optional(number, 100)
    disk_type          = optional(string, "pd-standard")
    labels             = optional(map(string), {})
    taints             = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    auto_repair  = optional(bool, true)
    auto_upgrade = optional(bool, true)
  }))
  default = {}
}

variable "enable_karpenter" {
  description = "Enable Karpenter for GKE (experimental)"
  type        = bool
  default     = false
}

variable "karpenter_config" {
  description = "Karpenter configuration for GKE (experimental)"
  type = object({
    chart_version = optional(string, "1.2.0")
    extra_sets    = optional(map(string), {})
  })
  default = null
}
