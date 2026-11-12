# declara vpc  
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block 
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags =  {
    Name = var.name
    terraform = "true"
  }
}
 
# declara subnets publicas
resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-${count.index + 1}"
    terraform = "true"
  }
}

# declara subnets privadas

resource "aws_subnet" "private_subnet" {
  count                   = length(var.private_subnets_cidr)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-private-${count.index + 1}"
    terraform = "true"
  }
}

