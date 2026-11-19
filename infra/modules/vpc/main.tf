# Cria a rede isolada para este ambiente.
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = var.name
    terraform = "true"
  }
}

# Cria as subnets públicas, quando o ambiente tiver alguma.
resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.name}-public-${count.index + 1}"
    terraform = "true"
  }
}

# Cria as subnets privadas usadas pelos workloads.
resource "aws_subnet" "private_subnet" {
  count                   = length(var.private_subnets_cidr)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${var.name}-private-${count.index + 1}"
    terraform = "true"
  }
}

# Cria subnets privadas dedicadas ao anexo do Transit Gateway.
resource "aws_subnet" "transit_subnet" {
  count                   = length(var.transit_subnets_cidr)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.transit_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${var.name}-transit-${count.index + 1}"
    terraform = "true"
  }
}

