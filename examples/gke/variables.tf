variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot mode"
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
  description = "CIDR for the control plane"
  type        = string
  default     = "172.16.0.0/28"
}

variable "release_channel" {
  description = "Release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "node_pools" {
  description = "Node pools (only used when autopilot is disabled)"
  type = map(object({
    machine_type       = optional(string, "e2-medium")
    min_count          = optional(number, 1)
    max_count          = optional(number, 10)
    initial_node_count = optional(number, 2)
    disk_size_gb       = optional(number, 100)
    labels             = optional(map(string), {})
    taints             = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {}
}

variable "enable_karpenter" {
  description = "Enable Karpenter for GKE (experimental)"
  type        = bool
  default     = false
}

variable "karpenter_config" {
  description = "Karpenter configuration for GKE"
  type = any
  default = null
}

variable "tags" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}
