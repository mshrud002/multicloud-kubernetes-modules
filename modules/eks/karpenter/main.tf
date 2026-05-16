data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  node_role_name = "KarpenterNodeRole-${var.cluster_name}"
}

resource "aws_iam_role" "karpenter_node" {
  count = var.node_role_arn == null ? 1 : 0
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

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  tags = var.tags
}

locals {
  node_role = var.node_role_arn != null ? var.node_role_arn : aws_iam_role.karpenter_node[0].arn
}

resource "aws_iam_role" "karpenter_irsa" {
  name = "KarpenterIRSA-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/oidc-provider\\///", "")}:sub" : "system:serviceaccount:kube-system:karpenter"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "karpenter" {
  name = "KarpenterPolicy-${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DeleteLaunchTemplate",
          "ec2:ModifyLaunchTemplate",
          "ec2:GetLaunchTemplateData",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeVpcEndpoints",
          "iam:PassRole",
          "pricing:GetProducts",
          "pricing:DescribeServices",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:DescribeNodegroup",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:eks:*:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcEndpoints",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:PassRole",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/Karpenter*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
        ]
        Resource = local.node_role
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/aws/service/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  role       = aws_iam_role.karpenter_irsa.name
  policy_arn = aws_iam_policy.karpenter.arn
}

resource "aws_ec2_tag" "karpenter_subnets" {
  for_each = var.subnet_selector_tags
  resource_id = "placeholder"
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "karpenter_security_groups" {
  for_each = var.security_group_tags
  resource_id = "placeholder"
  key         = each.key
  value       = each.value
}

resource "helm_release" "karpenter" {
  namespace  = "kube-system"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.2.0"

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_irsa.arn
  }

  set {
    name  = "settings.interruptionQueueName"
    value = "Karpenter-${var.cluster_name}"
  }

  values = [templatefile("${path.module}/values.yaml", {
    cluster_name = var.cluster_name
  })]
}

resource "aws_sqs_queue" "karpenter_interruption" {
  name = "Karpenter-${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = "*"
    }]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "karpenter_interruption" {
  name        = "Karpenter-${var.cluster_name}-interruption"
  description = "Capture EC2 interruption events for Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning", "EC2 Instance Rebalance Recommendation", "EC2 Instance State Change"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_interruption.name
  target_id = "Karpenter"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}
