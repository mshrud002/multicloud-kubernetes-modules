data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  auto_mode_enabled     = var.enable_auto_mode || (var.auto_mode_config != null && var.auto_mode_config.enabled)
  karpenter_enabled     = var.enable_karpenter || (var.karpenter_config != null)
  karpenter_crds_config = var.karpenter_crds_config != null ? var.karpenter_crds_config : {}
  lb_controller_enabled = var.enable_aws_lb_controller && !local.auto_mode_enabled

  cluster_role_name = "${var.cluster_name}-cluster-role"
  node_role_name    = "${var.cluster_name}-node-role"
}

resource "aws_iam_role" "cluster" {
  name = local.cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "node" {
  count = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1
  name  = local.node_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  count = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1
  role  = aws_iam_role.node[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  count = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1
  role  = aws_iam_role.node[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  count = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1
  role  = aws_iam_role.node[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  dynamic "compute_config" {
    for_each = local.auto_mode_enabled ? [1] : []
    content {
      enabled       = true
      node_role_arn = var.auto_mode_config != null && var.auto_mode_config.compute_config != null && var.auto_mode_config.compute_config.node_role_arn != null ? var.auto_mode_config.compute_config.node_role_arn : aws_iam_role.auto_mode_node[0].arn
      node_pools    = var.auto_mode_config != null && var.auto_mode_config.compute_config != null ? var.auto_mode_config.compute_config.node_pools : ["general-purpose", "system"]
    }
  }

  dynamic "storage_config" {
    for_each = local.auto_mode_enabled ? [1] : []
    content {
      enabled = var.auto_mode_config != null && var.auto_mode_config.storage_config != null ? var.auto_mode_config.storage_config.enabled : true
    }
  }

  dynamic "kubernetes_network_config" {
    for_each = local.auto_mode_enabled ? [1] : []
    content {
      elastic_load_balancing = var.auto_mode_config != null && var.auto_mode_config.networking_config != null ? {
        enabled = var.auto_mode_config.networking_config.enabled
      } : {
        enabled = true
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_resource_controller,
  ]

  tags = var.tags
}

resource "aws_iam_role" "auto_mode_node" {
  count = local.auto_mode_enabled ? 1 : 0
  name  = "${var.cluster_name}-auto-mode-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  tags = var.tags
}

resource "aws_eks_node_group" "this" {
  for_each = local.auto_mode_enabled || local.karpenter_enabled ? {} : var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node[0].arn
  subnet_ids      = var.subnet_ids

  instance_types = each.value.instance_types

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  disk_size = each.value.disk_size

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  labels = each.value.labels

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]

  tags = var.tags
}

module "karpenter" {
  count  = local.karpenter_enabled ? 1 : 0
  source = "./karpenter"

  cluster_name       = aws_eks_cluster.this.name
  cluster_endpoint   = aws_eks_cluster.this.endpoint
  oidc_provider_arn  = aws_eks_cluster.this.identity[0].oidc[0].issuer
  node_role_arn      = try(var.karpenter_config.node_role_arn, null)
  subnet_selector_tags = try(var.karpenter_config.subnet_selector_tags, {})
  security_group_tags  = try(var.karpenter_config.security_group_tags, {})
  instance_types       = try(var.karpenter_config.instance_types, ["c5.large", "m5.large", "r5.large"])
  ttl_seconds_after_empty = try(var.karpenter_config.ttl_seconds_after_empty, 30)
  tags = var.tags
}

resource "aws_eks_addon" "this" {
  for_each = var.addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value.addon_name
  addon_version               = each.value.addon_version
  resolve_conflicts_on_create = each.value.resolve_conflicts
  resolve_conflicts_on_update = each.value.resolve_conflicts
  service_account_role_arn    = each.value.service_account_role_arn
  configuration_values        = each.value.configuration_values

  timeouts {
    create = try(each.value.create_timeout, "20m")
    delete = try(each.value.delete_timeout, "20m")
  }

  tags = var.tags

  depends_on = [aws_eks_cluster.this]
}

locals {
  keda_enabled      = var.enable_keda || var.keda_config != null
  traefik_enabled   = var.enable_traefik || var.traefik_config != null
  neuvector_enabled = var.enable_neuvector || var.neuvector_config != null
}

resource "helm_release" "keda" {
  count = local.keda_enabled ? 1 : 0

  name       = "keda"
  namespace  = try(var.keda_config.namespace, "keda")
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = try(var.keda_config.chart_version, "2.16.0")

  create_namespace = try(var.keda_config.create_namespace, true)

  dynamic "set" {
    for_each = var.keda_config.extra_sets != null ? var.keda_config.extra_sets : {}
    content {
      name  = set.key
      value = set.value
    }
  }

  set {
    name  = "replicaCount"
    value = try(var.keda_config.replica_count, 2)
  }

  set {
    name  = "metricsServer.enabled"
    value = try(var.keda_config.metrics_server_enabled, true)
  }

  set {
    name  = "serviceAccount.create"
    value = try(var.keda_config.irsa_role_arn, null) == null
  }

  set {
    name  = "serviceAccount.name"
    value = try(var.keda_config.service_account_name, "keda-operator")
  }

  dynamic "set" {
    for_each = try(var.keda_config.irsa_role_arn, null) != null ? [1] : []
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.keda_config.irsa_role_arn
    }
  }

  depends_on = [aws_eks_cluster.this, aws_eks_addon.this]
}

resource "helm_release" "traefik" {
  count = local.traefik_enabled ? 1 : 0

  name       = "traefik"
  namespace  = try(var.traefik_config.namespace, "traefik")
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = try(var.traefik_config.chart_version, "34.3.0")

  create_namespace = try(var.traefik_config.create_namespace, true)

  dynamic "set" {
    for_each = var.traefik_config.extra_sets != null ? var.traefik_config.extra_sets : {}
    content {
      name  = set.key
      value = set.value
    }
  }

  set {
    name  = "replicas"
    value = try(var.traefik_config.replicas, 2)
  }

  set {
    name  = "service.type"
    value = try(var.traefik_config.service_type, "LoadBalancer")
  }

  dynamic "set" {
    for_each = try(var.traefik_config.node_port_http, null) != null ? [1] : []
    content {
      name  = "service.spec.http.nodePort"
      value = var.traefik_config.node_port_http
    }
  }

  dynamic "set" {
    for_each = try(var.traefik_config.node_port_https, null) != null ? [1] : []
    content {
      name  = "service.spec.https.nodePort"
      value = var.traefik_config.node_port_https
    }
  }

  set {
    name  = "providers.kubernetesIngress.enabled"
    value = true
  }

  set {
    name  = "dashboard.enabled"
    value = try(var.traefik_config.dashboard_enabled, true)
  }

  set {
    name  = "dashboard.auth.basic.users"
    value = try(var.traefik_config.dashboard_auth, true) ? "admin:$$2y$$10$$abcdefghijklmnopqrstuv" : ""
  }

  dynamic "set" {
    for_each = try(var.traefik_config.acme_email, null) != null ? [1] : []
    content {
      name  = "certificatesResolvers.letsencrypt.acme.email"
      value = var.traefik_config.acme_email
    }
  }

  dynamic "set" {
    for_each = try(var.traefik_config.acme_email, null) != null ? [1] : []
    content {
      name  = "certificatesResolvers.letsencrypt.acme.storage"
      value = "/data/acme.json"
    }
  }

  dynamic "set" {
    for_each = try(var.traefik_config.acme_email, null) != null && try(var.traefik_config.acme_staging, true) ? [1] : []
    content {
      name  = "certificatesResolvers.letsencrypt.acme.caServer"
      value = "https://acme-staging-v02.api.letsencrypt.org/directory"
    }
  }

  depends_on = [aws_eks_cluster.this, aws_eks_addon.this]
}

resource "helm_release" "neuvector" {
  count = local.neuvector_enabled ? 1 : 0

  name       = "neuvector"
  namespace  = try(var.neuvector_config.namespace, "neuvector")
  repository = "https://neuvector.github.io/neuvector-helm"
  chart      = "core"
  version    = try(var.neuvector_config.chart_version, "2.7.4")

  create_namespace = try(var.neuvector_config.create_namespace, true)

  set {
    name  = "controller.replicas"
    value = try(var.neuvector_config.replicas, 3)
  }

  set {
    name  = "manager.enabled"
    value = try(var.neuvector_config.enable_webui, true)
  }

  set {
    name  = "manager.svc.type"
    value = try(var.neuvector_config.webui_service_type, "ClusterIP")
  }

  set {
    name  = "admissionwebhook.enabled"
    value = try(var.neuvector_config.enable_admission, true)
  }

  set {
    name  = "controller.autoScan"
    value = try(var.neuvector_config.enable_auto_scan, true)
  }

  set {
    name  = "controller.pvc.enabled"
    value = try(var.neuvector_config.persistent_volume, true)
  }

  set {
    name  = "controller.pvc.capacity"
    value = try(var.neuvector_config.storage_size, "10Gi")
  }

  dynamic "set" {
    for_each = try(var.neuvector_config.storage_class, null) != null ? [1] : []
    content {
      name  = "controller.pvc.storageClass"
      value = var.neuvector_config.storage_class
    }
  }

  set {
    name  = "prometheus.exporter.enabled"
    value = try(var.neuvector_config.metrics_enabled, true)
  }

  dynamic "set" {
    for_each = try(var.neuvector_config.registry_username, null) != null ? [1] : []
    content {
      name  = "registry"
      value = var.neuvector_config.registry_username
    }
  }

  dynamic "set" {
    for_each = try(var.neuvector_config.registry_password, null) != null ? [1] : []
    content {
      name  = "imagePullSecrets[0].name"
      value = "neuvector-pull-secret"
    }
  }

  dynamic "set" {
    for_each = try(var.neuvector_config.irsa_role_arn, null) != null ? [1] : []
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.neuvector_config.irsa_role_arn
    }
  }

  dynamic "set" {
    for_each = var.neuvector_config.extra_sets != null ? var.neuvector_config.extra_sets : {}
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [aws_eks_cluster.this, aws_eks_addon.this]
}

resource "null_resource" "karpenter_crds" {
  count = local.karpenter_enabled ? 1 : 0

  triggers = {
    cluster      = aws_eks_cluster.this.name
    node_role    = local.karpenter_enabled ? module.karpenter[0].node_role_arn : ""
    config_hash = md5(jsonencode(local.karpenter_crds_config))
  }

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
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ${jsonencode(try(local.karpenter_crds_config.default_nodepool.instance_categories, ["c", "m", "r"]))}
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: ${jsonencode(try(local.karpenter_crds_config.default_nodepool.exclude_instance_sizes, ["nano", "micro", "small"]))}
      nodeClassRef:
        name: default
  limits:
    cpu: ${try(local.karpenter_crds_config.default_nodepool.limits_cpu, "200")}
    memory: ${try(local.karpenter_crds_config.default_nodepool.limits_memory, "800Gi")}
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  role: ${split("/", module.karpenter[0].node_role_arn)[1]}
  subnetSelectorTerms:
    - tags:
        kubernetes.io/cluster/${var.cluster_name}: shared
  securityGroupSelectorTerms:
    - tags:
        kubernetes.io/cluster/${var.cluster_name}: owned
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: ${try(local.karpenter_crds_config.ec2_nodeclass.block_device_size, 100)}Gi
        volumeType: ${try(local.karpenter_crds_config.ec2_nodeclass.block_device_type, "gp3")}
        encrypted: true
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: ${try(local.karpenter_crds_config.ec2_nodeclass.http_hop_limit, 2)}
    httpTokens: ${try(local.karpenter_crds_config.ec2_nodeclass.http_tokens, "required")}
EOF
    EOT
  }

  depends_on = [module.karpenter, aws_eks_cluster.this, aws_eks_addon.this]
}

resource "null_resource" "karpenter_crds_gpu" {
  count = local.karpenter_enabled && try(local.karpenter_crds_config.gpu_nodepool.enabled, true) ? 1 : 0

  triggers = {
    cluster      = aws_eks_cluster.this.name
    config_hash = md5(jsonencode(local.karpenter_crds_config))
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<-EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ${jsonencode(try(local.karpenter_crds_config.gpu_nodepool.instance_families, ["g5", "g6", "p3", "p4", "p5"]))}
        - key: nvidia.com/gpu
          operator: Exists
      nodeClassRef:
        name: default
  limits:
    cpu: ${try(local.karpenter_crds_config.gpu_nodepool.limits_cpu, "100")}
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
EOF
    EOT
  }

  depends_on = [null_resource.karpenter_crds]
}

resource "null_resource" "karpenter_crds_arm64" {
  count = local.karpenter_enabled && try(local.karpenter_crds_config.arm64_nodepool.enabled, true) ? 1 : 0

  triggers = {
    cluster      = aws_eks_cluster.this.name
    config_hash = md5(jsonencode(local.karpenter_crds_config))
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<-EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: arm64
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["arm64"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ${jsonencode(try(local.karpenter_crds_config.arm64_nodepool.instance_families, ["m7g", "c7g", "r7g"]))}
      nodeClassRef:
        name: default
  limits:
    cpu: ${try(local.karpenter_crds_config.arm64_nodepool.limits_cpu, "50")}
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
EOF
    EOT
  }

  depends_on = [null_resource.karpenter_crds]
}

resource "aws_iam_role" "lb_controller" {
  count = local.lb_controller_enabled ? 1 : 0
  name  = "${var.cluster_name}-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_eks_cluster.this.identity[0].oidc[0].issuer
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "lb_controller" {
  count = local.lb_controller_enabled ? 1 : 0
  name  = "${var.cluster_name}-lb-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeCoipPools",
        "ec2:DescribeInstances",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeManagedPrefixLists",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVpcEndpoints",
        "ec2:DescribeVpcPeeringConnections",
        "ec2:DescribeVpcs",
        "ec2:GetCoipPoolUsage",
        "ec2:GetSecurityGroupsForVpc",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteRule",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:ModifyRule",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:SetWebACL",
        "iam:CreateServiceLinkedRole",
        "cognito-idp:DescribeUserPoolClient",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "waf:GetWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:DescribeProtection",
        "shield:GetSubscriptionState",
        "shield:ListAttacks",
        "shield:AssociateDRTLogBucket",
        "shield:DisassociateDRTLogBucket",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  count      = local.lb_controller_enabled ? 1 : 0
  role       = aws_iam_role.lb_controller[0].name
  policy_arn = aws_iam_policy.lb_controller[0].arn
}

resource "helm_release" "aws_lb_controller" {
  count = local.lb_controller_enabled ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = try(var.aws_lb_controller_config.namespace, "kube-system")
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = try(var.aws_lb_controller_config.chart_version, "1.9.0")

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller[0].arn
  }

  dynamic "set" {
    for_each = var.aws_lb_controller_config.extra_sets != null ? var.aws_lb_controller_config.extra_sets : {}
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lb_controller, aws_eks_cluster.this, aws_eks_addon.this]
}

resource "aws_iam_role" "cluster_autoscaler" {
  count = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1
  name  = "${var.cluster_name}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_eks_cluster.this.identity[0].oidc[0].issuer
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:cluster-autoscaler"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1
  name  = "${var.cluster_name}-cluster-autoscaler-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions",
        "eks:DescribeNodegroup",
        "eks:DescribeCluster",
        "eks:ListNodegroups",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count      = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1
  role       = aws_iam_role.cluster_autoscaler[0].name
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
}

resource "helm_release" "cluster_autoscaler" {
  count = local.auto_mode_enabled || local.karpenter_enabled ? 0 : 1

  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.43.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler[0].arn
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = true
  }

  set {
    name  = "rbac.create"
    value = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_autoscaler, aws_eks_cluster.this, aws_eks_addon.this]
}
