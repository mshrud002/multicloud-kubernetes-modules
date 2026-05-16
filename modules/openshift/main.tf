locals {
  is_rosa           = var.platform == "rosa"
  is_aro            = var.platform == "aro"
  hcp               = var.hosted_control_plane
  karpenter_enabled = var.enable_karpenter || var.karpenter_config != null
}

data "aws_caller_identity" "current" {
  count = local.is_rosa ? 1 : 0
}

resource "aws_iam_role" "openshift_cp" {
  count = local.is_rosa ? 1 : 0
  name  = "${var.cluster_name}-cp-role"

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
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]

  tags = var.tags
}

resource "aws_iam_role" "openshift_node" {
  count = local.is_rosa ? 1 : 0
  name  = "${var.cluster_name}-node-role"

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
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]

  tags = var.tags
}

resource "aws_iam_role" "openshift_support" {
  count = local.is_rosa ? 1 : 0
  name  = "${var.cluster_name}-support-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::710019948333:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = data.aws_caller_identity.current[0].account_id
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role" "openshift_installer" {
  count = local.is_rosa ? 1 : 0
  name  = "${var.cluster_name}-installer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::710019948333:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = data.aws_caller_identity.current[0].account_id
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "openshift_installer" {
  count = local.is_rosa ? 1 : 0
  name  = "${var.cluster_name}-installer-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["*"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "openshift_installer" {
  count = local.is_rosa ? 1 : 0
  role       = aws_iam_role.openshift_installer[0].name
  policy_arn = aws_iam_policy.openshift_installer[0].arn
}

resource "null_resource" "rosa_cluster" {
  count = local.is_rosa && !local.hcp ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      rosa create cluster \
        --cluster-name ${var.cluster_name} \
        --region ${var.aws.region} \
        --version ${var.openshift_version} \
        --machine-cidr ${var.aws.machine_cidr} \
        --service-cidr ${var.aws.service_cidr} \
        --pod-cidr ${var.aws.pod_cidr} \
        --host-prefix ${var.aws.host_prefix} \
        --compute-machine-type ${var.aws.compute_machine_type} \
        --compute-nodes ${var.aws.replicas} \
        --node-disk-size ${var.aws.node_disk_size} \
        --roles-arn installer:${aws_iam_role.openshift_installer[0].arn} \
        --roles-arn support:${aws_iam_role.openshift_support[0].arn} \
        --roles-arn controlplane:${aws_iam_role.openshift_cp[0].arn} \
        --roles-arn worker:${aws_iam_role.openshift_node[0].arn} \
        ${var.aws.vpc_id != null ? "--subnet-ids ${join(",", var.aws.subnet_ids)}" : ""} \
        --private ${var.aws.public_subnet_ids == null && var.aws.private_subnet_ids != null ? "--private" : ""} \
        --watch
    EOT
  }
}

resource "null_resource" "rosa_hcp_cluster" {
  count = local.is_rosa && local.hcp ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      rosa create cluster \
        --cluster-name ${var.cluster_name} \
        --region ${var.aws.region} \
        --version ${var.openshift_version} \
        --hosted-cp \
        --machine-cidr ${var.aws.machine_cidr} \
        --service-cidr ${var.aws.service_cidr} \
        --pod-cidr ${var.aws.pod_cidr} \
        --host-prefix ${var.aws.host_prefix} \
        --compute-machine-type ${var.aws.compute_machine_type} \
        --compute-nodes ${var.aws.replicas} \
        --node-disk-size ${var.aws.node_disk_size} \
        --roles-arn installer:${aws_iam_role.openshift_installer[0].arn} \
        --roles-arn support:${aws_iam_role.openshift_support[0].arn} \
        --roles-arn controlplane:${aws_iam_role.openshift_cp[0].arn} \
        ${var.aws.vpc_id != null ? "--subnet-ids ${join(",", var.aws.subnet_ids)}" : ""} \
        --private ${var.aws.public_subnet_ids == null && var.aws.private_subnet_ids != null ? "--private" : ""} \
        --watch
    EOT
  }
}

resource "null_resource" "aro_cluster" {
  count = local.is_aro ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      az aro create \
        --resource-group ${var.azure.resource_group} \
        --name ${var.cluster_name} \
        --location ${var.azure.location} \
        --version ${var.openshift_version} \
        --vnet ${var.azure.vnet_id} \
        --master-subnet ${var.azure.master_subnet_id} \
        --worker-subnet ${var.azure.worker_subnet_id} \
        --cluster-resource-group ${var.azure.cluster_rg} \
        --worker-count ${var.aws.replicas} \
        --worker-vm-size ${var.aws.compute_machine_type}
    EOT
  }
}

resource "null_resource" "machine_pools" {
  for_each = var.machine_pools

  provisioner "local-exec" {
    command = <<-EOT
      rosa create machinepool \
        --cluster ${var.cluster_name} \
        --name ${each.key} \
        --instance-type ${each.value.machine_type} \
        --replicas ${each.value.replicas} \
        --enable-autoscaling \
        --min-replicas ${each.value.min_replicas} \
        --max-replicas ${each.value.max_replicas} \
        --labels ${jsonencode(each.value.labels)} \
        ${length(each.value.taints) > 0 ? "--taints ${jsonencode([for t in each.value.taints : "${t.key}=${t.value}:${t.effect}"])}" : ""}
    EOT
  }
}

resource "null_resource" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      oc apply -f - <<-EOF
apiVersion: "autoscaling.openshift.io/v1"
kind: "ClusterAutoscaler"
metadata:
  name: "default"
spec:
  podPriorityThreshold:
    defaultPriority: -10
  resourceLimits:
    maxNodesTotal: 100
    cores:
      min: 8
      max: 256
    memory:
      min: 32
      max: 1024
  scaleDown:
    enabled: true
    delayAfterAdd: ${var.cluster_autoscaler_config.scale_down_delay_after_add}
    delayAfterDelete: ${var.cluster_autoscaler_config.scale_down_delay_after_delete}
    delayAfterFailure: ${var.cluster_autoscaler_config.scale_down_delay_after_failure}
    unneededTime: ${var.cluster_autoscaler_config.scale_down_unneeded_time}
    unreadyTime: ${var.cluster_autoscaler_config.scale_down_unready_time}
EOF
    EOT
  }
}

resource "helm_release" "karpenter_openshift" {
  count = local.karpenter_enabled ? 1 : 0

  name       = "karpenter"
  namespace  = try(var.karpenter_config.namespace, "kube-system")
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = try(var.karpenter_config.chart_version, "1.2.0")

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = local.is_rosa ? "https://api.${var.cluster_name}.${var.aws.region}.openshift.com:6443" : ""
  }

  set {
    name  = "settings.interruptionQueueName"
    value = ""
  }

  dynamic "set" {
    for_each = try(var.karpenter_config.extra_sets, {})
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "null_resource" "karpenter_crds_openshift" {
  count = local.karpenter_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      oc apply -f - <<-EOF
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

  depends_on = [helm_release.karpenter_openshift]
}
