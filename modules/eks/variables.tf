variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
}

variable "enable_auto_mode" {
  description = "Enable EKS Auto Mode (AWS-managed compute, networking, scaling)"
  type        = bool
  default     = false
}

variable "auto_mode_config" {
  description = "Configuration for EKS Auto Mode"
  type = object({
    enabled       = bool
    node_pools    = optional(list(string), ["general-purpose", "system"])
    compute_config = optional(object({
      enabled       = bool
      node_role_arn = optional(string)
      node_pools    = optional(list(string), ["general-purpose", "system"])
    }))
    storage_config = optional(object({
      enabled = bool
    }))
    networking_config = optional(object({
      enabled = bool
      security_group_ids = optional(list(string))
      subnet_ids         = optional(list(string))
    }))
  })
  default = null
}

variable "enable_karpenter" {
  description = "Enable Karpenter node autoscaling"
  type        = bool
  default     = false
}

variable "karpenter_config" {
  description = "Karpenter configuration"
  type = object({
    node_role_arn         = optional(string)
    subnet_selector_tags  = optional(map(string))
    security_group_tags   = optional(map(string))
    instance_types        = optional(list(string), ["c5.large", "m5.large", "r5.large"])
    ttl_seconds_after_empty = optional(number, 30)
  })
  default = null
}

variable "node_groups" {
  description = "Managed node groups configuration (used when auto_mode and karpenter are disabled)"
  type = map(object({
    instance_types   = list(string)
    desired_size     = optional(number, 2)
    min_size         = optional(number, 1)
    max_size         = optional(number, 10)
    disk_size        = optional(number, 20)
    labels           = optional(map(string), {})
    taints           = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {}
}

variable "addons" {
  description = "EKS addons to deploy"
  type = map(object({
    addon_name           = string
    addon_version        = optional(string)
    resolve_conflicts    = optional(string, "OVERWRITE")
    service_account_role_arn = optional(string)
    configuration_values = optional(string)
    create_timeout       = optional(string)
    delete_timeout       = optional(string)
  }))
  default = {
    vpc-cni = {
      addon_name = "vpc-cni"
    }
    coredns = {
      addon_name = "coredns"
    }
    kube-proxy = {
      addon_name = "kube-proxy"
    }
  }
}

variable "karpenter_crds_config" {
  description = "Karpenter NodePool and EC2NodeClass CRD configuration (applied after Karpenter Helm install)"
  type = object({
    default_nodepool = optional(object({
      limits_cpu    = optional(string, "200")
      limits_memory = optional(string, "800Gi")
      instance_categories = optional(list(string), ["c", "m", "r"])
      exclude_instance_sizes = optional(list(string), ["nano", "micro", "small"])
    }), {})
    gpu_nodepool = optional(object({
      enabled      = optional(bool, true)
      limits_cpu   = optional(string, "100")
      instance_families = optional(list(string), ["g5", "g6", "p3", "p4", "p5"])
    }), {})
    arm64_nodepool = optional(object({
      enabled      = optional(bool, true)
      limits_cpu   = optional(string, "50")
      instance_families = optional(list(string), ["m7g", "c7g", "r7g"])
    }), {})
    ec2_nodeclass = optional(object({
      block_device_size = optional(number, 100)
      block_device_type = optional(string, "gp3")
      http_tokens       = optional(string, "required")
      http_hop_limit    = optional(number, 2)
    }), {})
  })
  default = null
}

variable "enable_aws_lb_controller" {
  description = "Enable AWS Load Balancer Controller (deploys aws-load-balancer-controller Helm chart)"
  type        = bool
  default     = true
}

variable "aws_lb_controller_config" {
  description = "AWS Load Balancer Controller configuration"
  type = object({
    chart_version = optional(string, "1.9.0")
    namespace     = optional(string, "kube-system")
    extra_sets    = optional(map(string), {})
  })
  default = null
}

variable "enable_keda" {
  description = "Enable KEDA (Kubernetes Event-Driven Autoscaling)"
  type        = bool
  default     = false
}

variable "keda_config" {
  description = "KEDA Helm chart configuration"
  type = object({
    chart_version          = optional(string, "2.16.0")
    namespace              = optional(string, "keda")
    create_namespace       = optional(bool, true)
    service_account_name   = optional(string, "keda-operator")
    irsa_role_arn          = optional(string)
    replica_count          = optional(number, 2)
    metrics_server_enabled = optional(bool, true)
    extra_sets             = optional(map(string), {})
  })
  default = null
}

variable "enable_traefik" {
  description = "Enable Traefik ingress controller"
  type        = bool
  default     = false
}

variable "traefik_config" {
  description = "Traefik Helm chart configuration"
  type = object({
    chart_version        = optional(string, "34.3.0")
    namespace            = optional(string, "traefik")
    create_namespace     = optional(bool, true)
    service_type         = optional(string, "LoadBalancer")
    replicas             = optional(number, 2)
    proxy_protocol       = optional(bool, false)
    ssl_enabled          = optional(bool, true)
    acme_email           = optional(string)
    acme_staging         = optional(bool, true)
    dashboard_enabled    = optional(bool, true)
    dashboard_auth       = optional(bool, true)
    node_port_http       = optional(number)
    node_port_https      = optional(number)
    extra_sets           = optional(map(string), {})
  })
  default = null
}

variable "enable_neuvector" {
  description = "Enable NeuVector container security platform"
  type        = bool
  default     = false
}

variable "neuvector_config" {
  description = "NeuVector Helm chart configuration"
  type = object({
    chart_version        = optional(string, "2.7.4")
    namespace            = optional(string, "neuvector")
    create_namespace     = optional(bool, true)
    replicas             = optional(number, 3)
    persistent_volume    = optional(bool, true)
    storage_size         = optional(string, "10Gi")
    storage_class        = optional(string)
    metrics_enabled      = optional(bool, true)
    enable_webui         = optional(bool, true)
    webui_service_type   = optional(string, "ClusterIP")
    enable_admission     = optional(bool, true)
    enable_auto_scan     = optional(bool, true)
    registry_username    = optional(string)
    registry_password    = optional(string, "", true)
    irsa_role_arn        = optional(string)
    extra_sets           = optional(map(string), {})
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
