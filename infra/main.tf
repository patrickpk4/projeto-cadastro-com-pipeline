module "vpc" {
  source               = "./modules/vpc"
  for_each             = var.vpcs
  name                 = each.key
  cidr_block           = each.value.cidr_block
  availability_zones   = each.value.availability_zones
  public_subnets_cidr  = each.value.public_subnets_cidr
  private_subnets_cidr = each.value.private_subnets_cidr
  transit_subnets_cidr = each.value.transit_subnets_cidr
}

module "network" {
  source            = "./modules/network"
  vpc_id            = module.vpc["hub"].vpc_id
  public_subnet_ids = module.vpc["hub"].public_subnet_ids
}

module "transit_gateway" {
  source = "./modules/transit-gateway"

  hub_vpc_id                = module.vpc["hub"].vpc_id
  hub_transit_subnet_ids    = module.vpc["hub"].transit_subnet_ids
  hub_nat_gateway_id        = module.network.nat_gateway_id
  hub_public_route_table_id = module.network.public_route_table_id
  spoke_vpcs = {
    for name, vpc in var.vpcs : name => {
      vpc_id             = module.vpc[name].vpc_id
      cidr_block         = vpc.cidr_block
      private_subnet_ids = module.vpc[name].private_subnet_ids
    }
    if name != "hub"
  }
}

################### module eks ############################

module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "~> 21.0"
  for_each           = var.eks
  name               = each.key
  kubernetes_version = each.value.version


  endpoint_public_access  = true
  endpoint_private_access = true


  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = each.value.nodepools
  }

  vpc_id     = module.vpc[each.value.env].vpc_id
  subnet_ids = module.vpc[each.value.env].private_subnet_ids

  tags = {
    Environment = each.value.env
    Terraform   = "true"
  }
}
