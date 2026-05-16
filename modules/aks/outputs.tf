output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.fqdn
}

output "kube_config" {
  description = "Kube config for the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "node_resource_group" {
  description = "Auto-generated resource group for node resources"
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "automatic_mode_enabled" {
  description = "Whether AKS Automatic mode is enabled"
  value       = local.automatic_mode
}

output "node_auto_provisioning_enabled" {
  description = "Whether Node Auto Provisioning is enabled"
  value       = local.nap_enabled
}

output "karpenter_enabled" {
  description = "Whether Karpenter is enabled for AKS"
  value       = local.karpenter_enabled
}

output "karpenter_namespace" {
  description = "Namespace where Karpenter is deployed"
  value       = local.karpenter_enabled ? "kube-system" : null
}
