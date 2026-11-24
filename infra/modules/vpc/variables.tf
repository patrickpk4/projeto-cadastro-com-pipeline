# Nome usado nas tags das redes.
variable "name" {
  type = string
}

# Faixa de endereços IP reservada para a VPC.
variable "cidr_block" {
  type = string
}

# Zonas de disponibilidade usadas para distribuir as subnets.
variable "availability_zones" {
  type = list(string)
}

# Faixas de IP das subnets públicas.
variable "public_subnets_cidr" {
  type = list(string)
}

# Faixas de IP das subnets privadas de workloads.
variable "private_subnets_cidr" {
  type = list(string)
}

# Faixas de IP das subnets de trânsito da VPC hub.
variable "transit_subnets_cidr" {
  type = list(string)
}

