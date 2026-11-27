data "terraform_remote_state" "hub" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.hub_state_key
    region = var.aws_region
  }
}

module "vpc" {
  source               = "../modules/vpc"
  name                 = "${var.environment}-vpc"
  cidr_block           = var.vpc.cidr_block
  availability_zones   = var.vpc.availability_zones
  public_subnets_cidr  = var.vpc.public_subnets_cidr
  private_subnets_cidr = var.vpc.private_subnets_cidr
  transit_subnets_cidr = var.vpc.transit_subnets_cidr
}

module "eks" {
  count = 1
  # This commit is the upstream v21.30.2 release.
  source             = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=25c846a384bc66d16cc801d2f851431deb38de5d"
  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access  = true
  endpoint_private_access = true
  encryption_config = {
    resources = ["secrets"]
  }

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = var.nodepools
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_to_eks" {
  count = 1

  description                  = "Application traffic from the shared hub ALB"
  security_group_id            = module.eks[0].cluster_primary_security_group_id
  referenced_security_group_id = data.terraform_remote_state.hub.outputs.hub_load_balancer_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}
