locals {
  autopilot         = var.enable_autopilot
  karpenter_enabled = var.enable_karpenter || var.karpenter_config != null
}

data "google_client_config" "current" {}

resource "google_service_account" "cluster" {
  account_id   = "${var.cluster_name}-gke-sa"
  display_name = "GKE Cluster Service Account - ${var.cluster_name}"
}

resource "google_project_iam_member" "cluster_sa_roles" {
  for_each = toset([
    "roles/container.nodeServiceAccount",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cluster.email}"
}

resource "google_service_account" "karpenter" {
  count = local.karpenter_enabled ? 1 : 0

  account_id   = "${var.cluster_name}-karpenter-sa"
  display_name = "Karpenter Service Account - ${var.cluster_name}"
}

resource "google_project_iam_member" "karpenter_sa_roles" {
  for_each = local.karpenter_enabled ? toset([
    "roles/compute.instanceAdmin.v1",
    "roles/compute.networkViewer",
    "roles/iam.serviceAccountUser",
  ]) : toset([])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.karpenter[0].email}"
}

resource "google_container_cluster" "this" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  enable_autopilot = local.autopilot

  initial_node_count = local.autopilot ? null : 1

  min_master_version = var.kubernetes_version
  release_channel {
    channel = var.release_channel
  }

  network    = var.network
  subnetwork = var.subnetwork

  private_cluster_config {
    enable_private_nodes   = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = null
    services_secondary_range_name = null
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "all"
    }
  }

  dynamic "maintenance_window" {
    for_each = length(keys(var.maintenance_window)) > 0 ? [1] : []
    content {
      recurring_window {
        start_time = var.maintenance_window.start_time
        recurrence = var.maintenance_window.recurring
      }
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = true
    }
  }

  cluster_autoscaling {
    enabled = true
    dynamic "auto_provisioning_defaults" {
      for_each = local.autopilot ? [] : [1]
      content {
        service_account = google_service_account.cluster.email
        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform",
        ]
      }
    }
  }

  resource_labels = var.cluster_resource_labels

  depends_on = [google_project_iam_member.cluster_sa_roles]

  lifecycle {
    ignore_changes = [
      node_pool,
      node_config,
    ]
  }
}

resource "google_container_node_pool" "primary_nodes" {
  for_each = local.autopilot ? {} : var.node_pools

  name     = each.key
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.this.name

  initial_node_count = each.value.initial_node_count

  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = each.value.disk_size_gb
    disk_type       = each.value.disk_type
    service_account = google_service_account.cluster.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = merge(each.value.labels, var.cluster_resource_labels)

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

resource "helm_release" "karpenter_gke" {
  count = local.karpenter_enabled ? 1 : 0

  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = try(var.karpenter_config.chart_version, "1.2.0")

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = google_container_cluster.this.endpoint
  }

  set {
    name  = "settings.interruptionQueueName"
    value = ""
  }

  set {
    name  = "serviceAccount.annotations.gcp\\.serviceAccount"
    value = google_service_account.karpenter[0].email
  }

  dynamic "set" {
    for_each = try(var.karpenter_config.extra_sets, {})
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [google_container_cluster.this]
}

resource "null_resource" "karpenter_crds_gke" {
  count = local.karpenter_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<-EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]
      nodeClassRef:
        name: default
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
---
apiVersion: karpenter.k8s.gcp/v1
kind: GCENodeClass
metadata:
  name: default
spec:
  projectID: ${var.project_id}
  tags:
    karpenter.sh/discovery: ${var.cluster_name}
EOF
    EOT
  }

  depends_on = [helm_release.karpenter_gke]
}
