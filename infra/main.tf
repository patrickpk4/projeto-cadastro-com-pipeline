module "vpc" {
  source               = "./modules"
  for_each             = var.vpcs
  name                 = each.key
  cidr_block           = each.value.cidr_block
  availability_zones   = each.value.availability_zones
  public_subnets_cidr  = each.value.public_subnets_cidr
  private_subnets_cidr = each.value.private_subnets_cidr

}