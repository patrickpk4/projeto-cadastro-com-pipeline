############################# VPC ################################
module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "6.6.1"
  name               = var.vpc_name
  cidr               = var.cidr_vpc
  azs                = var.azs_subnets
  private_subnets    = var.cidr_private_sub
  public_subnets     = var.cidr_public_sub
  enable_nat_gateway = true
  enable_vpn_gateway = true
  tags               = var.project_tags
}
########################### EKS #####################################
module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "~> 21.0"
  name               = var.kube_name
  kubernetes_version = var.kube_version
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }
  endpoint_public_access                   = true
  endpoint_private_access                  = true
  enable_cluster_creator_admin_permissions = true
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  eks_managed_node_groups = {
    example = {
      instance_types       = var.instance_types
      min_size             = 2
      max_size             = 4
      desired_size         = 2
      bootstrap_extra_args = "--max-pods 110"
    }
  }
  tags = var.project_tags
}