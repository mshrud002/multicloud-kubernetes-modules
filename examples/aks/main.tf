provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_resource_group" "existing" {
  count = var.resource_group_name != null ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name != null ? 0 : 1
  name     = "${var.cluster_name}-rg"
  location = var.location
}

locals {
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : azurerm_resource_group.this[0].name
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.cluster_name}-vnet"
  location            = var.location
  resource_group_name = local.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "this" {
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

module "aks" {
  source = "../../modules/aks"

  cluster_name          = var.cluster_name
  kubernetes_version    = var.kubernetes_version
  resource_group_name   = local.resource_group_name
  location              = var.location
  vnet_subnet_id        = azurerm_subnet.this.id

  # Choose ONE of the following:
  enable_automatic_mode         = var.enable_automatic_mode
  enable_node_auto_provisioning = var.enable_node_auto_provisioning

  node_pools = var.node_pools

  enable_karpenter = var.enable_karpenter
  karpenter_config = var.karpenter_config

  tags = var.tags
}
