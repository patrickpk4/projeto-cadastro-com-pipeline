# Cria uma VPC para cada ambiente definido em terraform.tfvars.
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

# Cria o IGW, NAT Gateway e ALB públicos na VPC hub.
module "network" {
  source                 = "./modules/network"
  vpc_id                 = module.vpc["hub"].vpc_id
  public_subnet_ids      = module.vpc["hub"].public_subnet_ids
  target_vpc_cidr_blocks = [for name, vpc in var.vpcs : vpc.cidr_block if name != "hub"]
  target_group_cluster_names = {
    for cluster_name, config in var.eks : config.env => cluster_name
  }
}

# Centraliza a saída para a internet das VPCs privadas pelo NAT do hub.
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

# Cria um cluster EKS para cada ambiente configurado.
module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "~> 21.0"
  for_each           = var.eks
  name               = each.key
  kubernetes_version = each.value.version


  endpoint_public_access  = true
  endpoint_private_access = true


  enable_cluster_creator_admin_permissions = true

  # Habilita o EKS Auto Mode com os pools escolhidos para o cluster.
  compute_config = {
    enabled    = true
    node_pools = each.value.nodepools
  }

  vpc_id     = module.vpc[each.value.env].vpc_id
  subnet_ids = module.vpc[each.value.env].private_subnet_ids

  # Identifica o ambiente e os recursos gerenciados por Terraform.
  tags = {
    Environment = each.value.env
    Terraform   = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_to_eks" {
  for_each = var.eks

  description                  = "Application traffic from the hub ALB"
  security_group_id            = module.eks[each.key].cluster_primary_security_group_id
  referenced_security_group_id = module.network.load_balancer_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080

  depends_on = [module.transit_gateway]
}
