provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "current" {}

module "gke" {
  source = "../../modules/gke"

  cluster_name    = var.cluster_name
  project_id      = var.project_id
  region          = var.region
  kubernetes_version = var.kubernetes_version

  # Autopilot mode (Google-managed nodes)
  enable_autopilot = var.enable_autopilot

  network    = var.network
  subnetwork = var.subnetwork

  master_ipv4_cidr_block = var.master_ipv4_cidr_block
  release_channel        = var.release_channel

  # Node pools (only used when autopilot is disabled)
  node_pools = var.node_pools

  enable_karpenter = var.enable_karpenter
  karpenter_config = var.karpenter_config

  cluster_resource_labels = var.tags
}
