provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  tags = var.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  enable_auto_mode = var.enable_auto_mode
  enable_karpenter = var.enable_karpenter
  karpenter_config = var.enable_karpenter ? {
    subnet_selector_tags = {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
    security_group_tags = {}
    instance_types      = ["c5.large", "m5.large", "r5.large"]
  } : null
  karpenter_crds_config = var.enable_karpenter ? var.karpenter_crds_config : null

  node_groups = var.node_groups
  addons      = var.addons

  enable_aws_lb_controller = var.enable_aws_lb_controller
  aws_lb_controller_config = var.aws_lb_controller_config

  enable_keda    = var.enable_keda
  keda_config    = var.keda_config
  enable_traefik  = var.enable_traefik
  traefik_config  = var.traefik_config
  enable_neuvector = var.enable_neuvector
  neuvector_config = var.neuvector_config
  tags            = var.tags
}
