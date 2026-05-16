provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true

  tags = var.tags
}

module "openshift" {
  source = "../../modules/openshift"

  cluster_name        = var.cluster_name
  platform            = "rosa"
  openshift_version   = var.openshift_version
  hosted_control_plane = var.hosted_control_plane

  aws = {
    region               = var.aws_region
    vpc_id               = module.vpc.vpc_id
    subnet_ids           = module.vpc.private_subnets
    machine_cidr         = "10.0.0.0/16"
    service_cidr         = "172.30.0.0/16"
    pod_cidr             = "10.128.0.0/14"
    host_prefix          = 23
    node_disk_size       = 120
    replicas             = 3
    compute_machine_type = "m5.xlarge"
  }

  machine_pools = var.machine_pools

  enable_cluster_autoscaler       = var.enable_cluster_autoscaler
  cluster_autoscaler_config       = var.cluster_autoscaler_config

  enable_karpenter = var.enable_karpenter
  karpenter_config = var.karpenter_config

  tags = var.tags
}
