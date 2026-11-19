# ID da VPC hub que recebe o anexo central.
variable "hub_vpc_id" {
  type = string
}

# IDs das subnets privadas do hub usadas pelo anexo do Transit Gateway.
variable "hub_transit_subnet_ids" {
  type = list(string)
}

# ID do NAT Gateway central que envia tráfego para a internet.
variable "hub_nat_gateway_id" {
  type = string
}

# Route table pública do hub, usada para devolver tráfego às VPCs privadas.
variable "hub_public_route_table_id" {
  type = string
}

# VPCs privadas conectadas ao hub, com suas faixas e subnets.
variable "spoke_vpcs" {
  type = map(object({
    vpc_id             = string       # ID da VPC privada.
    cidr_block         = string       # Faixa de IP usada nas rotas do Transit Gateway.
    private_subnet_ids = list(string) # Subnets privadas ligadas ao Transit Gateway.
  }))
}
