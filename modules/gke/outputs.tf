output "cluster_id" {
  description = "ID of the GKE cluster"
  value       = google_container_cluster.this.id
}

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "CA certificate of the GKE cluster"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Location (region/zone) of the GKE cluster"
  value       = google_container_cluster.this.location
}

output "service_account_email" {
  description = "Email of the GKE cluster service account"
  value       = google_service_account.cluster.email
}

output "autopilot_enabled" {
  description = "Whether GKE Autopilot is enabled"
  value       = local.autopilot
}

output "kubeconfig" {
  description = "Kubeconfig for the GKE cluster"
  value = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name    = google_container_cluster.this.name
    cluster_endpoint = google_container_cluster.this.endpoint
    cluster_ca      = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  })
  sensitive = true
}

output "karpenter_enabled" {
  description = "Whether Karpenter is enabled for GKE"
  value       = local.karpenter_enabled
}

output "karpenter_service_account" {
  description = "Karpenter GCP service account email"
  value       = local.karpenter_enabled ? google_service_account.karpenter[0].email : null
}
