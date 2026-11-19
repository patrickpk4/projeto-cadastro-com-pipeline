# Região AWS compartilhada pelos recursos e pelo provider.
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Mapa das VPCs; as listas de subnets podem ser vazias quando não se aplicam.
variable "vpcs" {
  type = map(object({
    cidr_block           = string       # Faixa de IPs da VPC.
    availability_zones   = list(string) # Zonas onde as subnets serão criadas.
    public_subnets_cidr  = list(string) # Faixas das subnets públicas.
    private_subnets_cidr = list(string) # Faixas das subnets privadas de workloads.
    transit_subnets_cidr = list(string) # Faixas privadas usadas pelo Transit Gateway no hub.
  }))
}

# Mapa dos clusters EKS e da VPC onde cada cluster será criado.
variable "eks" {
  type = map(object({
    version   = string       # Versão do Kubernetes.
    nodepools = list(string) # Pools do EKS Auto Mode habilitados.
    env       = string       # Nome da VPC usada pelo cluster.
  }))
}