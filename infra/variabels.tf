# Define a região AWS usada pelos recursos.
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Guarda a configuração de cada VPC e de suas subnets.
variable "vpcs" {
  type = map(object({
    cidr_block           = string       # Faixa de IPs da VPC.
    availability_zones   = list(string) # Zonas onde as subnets serão criadas.
    public_subnets_cidr  = list(string) # Faixas das subnets públicas.
    private_subnets_cidr = list(string) # Faixas das subnets privadas de workloads.
    transit_subnets_cidr = list(string) # Faixas privadas usadas pelo Transit Gateway no hub.
  }))
}

# Guarda as configurações de cada cluster EKS.
variable "eks" {
  type = map(object({
    version   = string       # Versão do Kubernetes.
    nodepools = list(string) # Pools do EKS Auto Mode habilitados.
    env       = string       # Nome da VPC usada pelo cluster.
  }))
}