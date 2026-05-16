variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "enable_auto_mode" {
  description = "Enable EKS Auto Mode"
  type        = bool
  default     = false
}

variable "enable_karpenter" {
  description = "Enable Karpenter"
  type        = bool
  default     = false
}

variable "karpenter_crds_config" {
  description = "Karpenter NodePool/EC2NodeClass configuration"
  type = any
  default = null
}

variable "node_groups" {
  description = "Managed node groups"
  type = map(object({
    instance_types = list(string)
    desired_size   = optional(number, 2)
    min_size       = optional(number, 1)
    max_size       = optional(number, 10)
    labels         = optional(map(string), {})
    taints         = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {}
}

variable "addons" {
  description = "EKS addons configuration"
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

variable "enable_aws_lb_controller" {
  description = "Enable AWS Load Balancer Controller"
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
  description = "Enable KEDA event-driven autoscaling"
  type        = bool
  default     = false
}

variable "keda_config" {
  description = "KEDA configuration"
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
  description = "Traefik configuration"
  type = object({
    chart_version     = optional(string, "34.3.0")
    namespace         = optional(string, "traefik")
    create_namespace  = optional(bool, true)
    service_type      = optional(string, "LoadBalancer")
    replicas          = optional(number, 2)
    proxy_protocol    = optional(bool, false)
    ssl_enabled       = optional(bool, true)
    acme_email        = optional(string)
    acme_staging      = optional(bool, true)
    dashboard_enabled = optional(bool, true)
    dashboard_auth    = optional(bool, true)
    node_port_http    = optional(number)
    node_port_https   = optional(number)
    extra_sets        = optional(map(string), {})
  })
  default = null
}

variable "enable_neuvector" {
  description = "Enable NeuVector container security"
  type        = bool
  default     = false
}

variable "neuvector_config" {
  description = "NeuVector configuration"
  type = object({
    chart_version      = optional(string, "2.7.4")
    namespace          = optional(string, "neuvector")
    create_namespace   = optional(bool, true)
    replicas           = optional(number, 3)
    persistent_volume  = optional(bool, true)
    storage_size       = optional(string, "10Gi")
    storage_class      = optional(string)
    metrics_enabled    = optional(bool, true)
    enable_webui       = optional(bool, true)
    webui_service_type = optional(string, "ClusterIP")
    enable_admission   = optional(bool, true)
    enable_auto_scan   = optional(bool, true)
    registry_username  = optional(string)
    irsa_role_arn      = optional(string)
    extra_sets         = optional(map(string), {})
  })
  default = null
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
