############################# VPC ################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = var.vpc_name
  cidr = var.cidr_vpc

  azs             = var.azs_subnets
  private_subnets = var.cidr_private_sub
  public_subnets  = var.cidr_public_sub

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = var.project_tags

}





########################### EKS ######################################



module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

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
          WARM_PREFIX_TARGET       = "1" # Ajuste conforme sua necessidade
          # WARM_IP_TARGET = "5"         # Alternativa ou complemento ao WARM_PREFIX_TARGET
          # MINIMUM_IP_TARGET = "10"     # Alternativa ou complemento ao WARM_PREFIX_TARGET
        }
      })
    }
  }

  # Optional
  endpoint_public_access  = true
  endpoint_private_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  # 1. Desabilita a criação automática das regras recomendadas pelo módulo
  node_security_group_enable_recommended_rules = false
  # Extend cluster security group rules
  security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    node_security_group_additional_rules = {
    ingress_cluster_9443_webhook = {
      description                   = "Control plane para webhook do OTel Operator"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  }


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    example = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      instance_types = var.instance_types

      min_size     = 2
      max_size     = 4
      desired_size = 2
    }
  }

  tags = var.project_tags
} 