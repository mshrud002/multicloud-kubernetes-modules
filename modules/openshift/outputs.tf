output "cluster_name" {
  description = "Name of the OpenShift cluster"
  value       = var.cluster_name
}

output "platform" {
  description = "Cloud platform for OpenShift (rosa/aro)"
  value       = var.platform
}

output "hosted_control_plane" {
  description = "Whether Hosted Control Planes (HyperShift) is enabled"
  value       = local.hcp
}

output "api_url" {
  description = "API URL of the OpenShift cluster"
  value       = local.is_rosa ? "https://api.${var.cluster_name}.${var.aws.region}.openshift.com:6443" : local.is_aro ? "https://api.${var.cluster_name}.${var.azure.location}.azmk8s.io:6443" : null
}

output "console_url" {
  description = "Console URL of the OpenShift cluster"
  value       = local.is_rosa ? "https://console-openshift-console.apps.${var.cluster_name}.${var.aws.region}.openshift.com" : local.is_aro ? "https://console-openshift-console.apps.${var.cluster_name}.${var.azure.location}.azmk8s.io" : null
}

output "cluster_autoscaler_enabled" {
  description = "Whether Cluster Autoscaler is enabled"
  value       = var.enable_cluster_autoscaler
}

output "machine_pool_names" {
  description = "Names of created machine pools"
  value       = keys(var.machine_pools)
}

output "karpenter_enabled" {
  description = "Whether Karpenter is enabled for OpenShift (experimental)"
  value       = local.karpenter_enabled
}
