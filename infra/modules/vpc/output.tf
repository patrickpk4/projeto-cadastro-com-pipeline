# Retorna o ID da VPC criada.
output "vpc_id" {
  value = aws_vpc.vpc.id
}

# Retorna os IDs das subnets públicas.
output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}

# Retorna os IDs das subnets privadas.
output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

# Retorna os IDs das subnets dedicadas ao Transit Gateway.
output "transit_subnet_ids" {
  value = aws_subnet.transit_subnet[*].id
}

# Retorna a faixa de IP da VPC.
output "vpc_cidr_block" {
  value = aws_vpc.vpc.cidr_block
}
