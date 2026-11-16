module "vpc" {
  source               = "./modules/vpc"
  for_each             = var.vpcs
  name                 = each.key
  cidr_block           = each.value.cidr_block
  availability_zones   = each.value.availability_zones
  public_subnets_cidr  = each.value.public_subnets_cidr
  private_subnets_cidr = each.value.private_subnets_cidr
}

module "network" {
  source             = "./modules/network"
  vpc_id             = module.vpc["hub"].vpc_id
  public_subnet_ids  = module.vpc["hub"].public_subnet_ids
  private_subnet_ids = module.vpc["hub"].private_subnet_ids
}