output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 encoded certificate data for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider for the cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "karpenter_irsa_role_arn" {
  description = "IAM role ARN for Karpenter IRSA"
  value       = local.karpenter_enabled ? module.karpenter[0].karpenter_role_arn : null
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN for Karpenter nodes"
  value       = local.karpenter_enabled ? module.karpenter[0].node_role_arn : null
}

output "auto_mode_enabled" {
  description = "Whether EKS Auto Mode is enabled"
  value       = local.auto_mode_enabled
}

output "karpenter_enabled" {
  description = "Whether Karpenter is enabled"
  value       = local.karpenter_enabled
}

output "addons" {
  description = "Map of EKS addon names to their versions"
  value = {
    for k, a in aws_eks_addon.this : k => {
      name    = a.addon_name
      version = a.addon_version
    }
  }
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "keda_enabled" {
  description = "Whether KEDA is enabled"
  value       = local.keda_enabled
}

output "keda_namespace" {
  description = "KEDA namespace"
  value       = local.keda_enabled ? try(var.keda_config.namespace, "keda") : null
}

output "traefik_enabled" {
  description = "Whether Traefik is enabled"
  value       = local.traefik_enabled
}

output "traefik_namespace" {
  description = "Traefik namespace"
  value       = local.traefik_enabled ? try(var.traefik_config.namespace, "traefik") : null
}

output "lb_controller_enabled" {
  description = "Whether AWS Load Balancer Controller is enabled"
  value       = local.lb_controller_enabled
}

output "karpenter_crds_applied" {
  description = "Whether Karpenter CRDs (NodePool, EC2NodeClass) have been applied"
  value       = local.karpenter_enabled
}

output "lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = local.lb_controller_enabled ? aws_iam_role.lb_controller[0].arn : null
}

output "cluster_autoscaler_enabled" {
  description = "Whether Cluster Autoscaler is enabled (only for managed node groups)"
  value       = !local.auto_mode_enabled && !local.karpenter_enabled
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = !local.auto_mode_enabled && !local.karpenter_enabled ? aws_iam_role.cluster_autoscaler[0].arn : null
}
