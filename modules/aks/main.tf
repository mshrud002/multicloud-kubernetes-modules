locals {
  automatic_mode     = var.enable_automatic_mode || var.automatic_sku == "Automatic"
  nap_enabled        = var.enable_node_auto_provisioning
  use_default_pool   = !local.automatic_mode && !local.nap_enabled
  karpenter_enabled  = var.enable_karpenter || var.karpenter_config != null
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  sku_tier = local.automatic_mode ? "Standard" : "Free"

  identity {
    type = var.identity_type
  }

  dynamic "default_node_pool" {
    for_each = local.use_default_pool ? [1] : []
    content {
      name                = "default"
      vm_size             = "Standard_DS2_v2"
      desired_count       = 2
      min_count           = 1
      max_count           = 10
      enable_auto_scaling = true
      vnet_subnet_id      = var.vnet_subnet_id
    }
  }

  dynamic "default_node_pool" {
    for_each = local.nap_enabled ? [1] : []
    content {
      name                  = "default"
      vm_size               = "Standard_DS2_v2"
      desired_count         = 2
      min_count             = 1
      max_count             = 10
      enable_auto_scaling   = true
      enable_node_public_ip = false
      vnet_subnet_id        = var.vnet_subnet_id

      upgrade_settings {
        max_surge = "10%"
      }
    }
  }

  dynamic "auto_scaler_profile" {
    for_each = local.nap_enabled || local.use_default_pool ? [1] : []
    content {
      balance_similar_node_groups      = true
      expander                         = "random"
      max_graceful_termination_sec     = 600
      max_node_provisioning_time       = "15m"
      max_unready_nodes                = 3
      max_unready_percentage           = 45
      new_pod_scale_up_delay           = "0s"
      scale_down_delay_after_add       = "10m"
      scale_down_delay_after_delete    = "10s"
      scale_down_delay_after_failure   = "3m"
      scale_down_unneeded              = "10m"
      scale_down_unready               = "20m"
      scan_interval                    = "10s"
      skip_nodes_with_local_storage    = false
      skip_nodes_with_system_pods      = true
    }
  }

  dynamic "node_provisioning_profile" {
    for_each = local.nap_enabled ? [1] : []
    content {
      mode = "Auto"
    }
  }

  dynamic "oms_agent" {
    for_each = local.automatic_mode ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.this[0].workspace_id
    }
  }

  network_profile {
    network_plugin    = var.network_profile.network_plugin
    network_policy    = var.network_profile.network_policy
    load_balancer_sku = var.network_profile.load_balancer_sku
    outbound_type     = var.network_profile.outbound_type
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  storage_profile {
    blob_driver_enabled = true
    disk_driver_enabled = true
    file_driver_enabled = true
  }

  tags = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  count = local.automatic_mode ? 1 : 0

  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "additional" {
  for_each = local.automatic_mode || local.nap_enabled ? {} : var.node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  desired_count         = each.value.desired_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  os_disk_size_gb       = each.value.os_disk_size_gb
  vnet_subnet_id        = var.vnet_subnet_id
  enable_auto_scaling   = each.value.enable_auto_scaling
  node_taints           = each.value.taints
  node_labels           = each.value.labels
  zones                 = each.value.availability_zones

  upgrade_settings {
    max_surge = "10%"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = var.vnet_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

resource "azurerm_container_registry" "this" {
  count = local.automatic_mode ? 1 : 0

  name                = replace(var.cluster_name, "-", "")
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = var.tags
}

resource "azurerm_role_assignment" "acr_attach" {
  count = local.automatic_mode ? 1 : 0

  scope                = azurerm_container_registry.this[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_federated_identity_credential" "karpenter" {
  count = local.karpenter_enabled ? 1 : 0

  name                = "karpenter"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_kubernetes_cluster.this.identity[0].principal_id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:kube-system:karpenter"
}

resource "helm_release" "karpenter_aks" {
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
    value = azurerm_kubernetes_cluster.this.fqdn
  }

  set {
    name  = "settings.interruptionQueueName"
    value = ""
  }

  set {
    name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
    value = try(var.karpenter_config.identity_client_id, "")
  }

  dynamic "set" {
    for_each = try(var.karpenter_config.extra_sets, {})
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [azurerm_kubernetes_cluster.this]
}

resource "null_resource" "karpenter_crds_aks" {
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
          values: ["on-demand"]
      nodeClassRef:
        name: default
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
EOF
    EOT
  }

  depends_on = [helm_release.karpenter_aks]
}
