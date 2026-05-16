variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the cluster"
  type        = string
}

variable "node_role_arn" {
  description = "Existing node IAM role ARN (optional, created if not provided)"
  type        = string
  default     = null
}

variable "subnet_selector_tags" {
  description = "Tags used to select subnets for Karpenter"
  type        = map(string)
  default     = {}
}

variable "security_group_tags" {
  description = "Tags used to select security groups for Karpenter"
  type        = map(string)
  default     = {}
}

variable "instance_types" {
  description = "Default instance types for Karpenter NodePool"
  type        = list(string)
  default     = ["c5.large", "m5.large", "r5.large"]
}

variable "ttl_seconds_after_empty" {
  description = "Time-to-live seconds after node is empty before Karpenter terminates it"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
