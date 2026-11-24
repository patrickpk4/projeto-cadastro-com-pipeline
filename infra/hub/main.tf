module "vpc" {
  source = "../modules/vpc"

  name                 = "hub-vpc"
  cidr_block           = var.vpc.cidr_block
  availability_zones   = var.vpc.availability_zones
  public_subnets_cidr  = var.vpc.public_subnets_cidr
  private_subnets_cidr = var.vpc.private_subnets_cidr
  transit_subnets_cidr = var.vpc.transit_subnets_cidr
}

module "network" {
  count  = 1
  source = "../modules/network"

  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  transit_subnet_ids         = module.vpc.transit_subnet_ids
  target_vpc_cidr_blocks     = var.peer_vpc_cidrs
  target_group_cluster_names = var.cluster_names
}

module "transit_gateway" {
  count  = 1
  source = "../modules/transit-gateway"

  hub_vpc_id             = module.vpc.vpc_id
  hub_transit_subnet_ids = module.vpc.transit_subnet_ids
}
