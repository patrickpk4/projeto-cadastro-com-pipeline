# declara internet gateway
resource "aws_internet_gateway" "hub" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "igw-hub"
    terraform = "true"
  }
}
# declara route table
resource "aws_route_table" "hub_public" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "rt-hub-public"
    terraform = "true"
  }
}
# declara rora para internet 
resource "aws_route" "hub_public_internet" {
  route_table_id         = aws_route_table.hub_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.hub.id
}
# declara associação da route table com as subnets públicas
resource "aws_route_table_association" "hub_public" {
  count          = length(var.public_subnet_ids)
  subnet_id      = var.public_subnet_ids[count.index]
  route_table_id = aws_route_table.hub_public.id
}

# Declara um IP público fixo para o NAT Gateway.
resource "aws_eip" "hub_nat" {
  domain = "vpc"

  tags = {
    Name      = "eip-nat-hub"
    terraform = "true"
  }
}

# O NAT Gateway fica em uma subnet pública com rota para o Internet Gateway.
resource "aws_nat_gateway" "hub" {
  allocation_id = aws_eip.hub_nat.id
  subnet_id     = var.public_subnet_ids[0]

  tags = {
    Name      = "natgw-hub"
    terraform = "true"
  }

  depends_on = [aws_route_table_association.hub_public]
}

# Encaminha o tráfego das subnets privadas pelo NAT Gateway.
resource "aws_route_table" "hub_private" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "rt-hub-private"
    terraform = "true"
  }
}

resource "aws_route" "hub_private_internet" {
  route_table_id         = aws_route_table.hub_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.hub.id
}

resource "aws_route_table_association" "hub_private" {
  count          = length(var.private_subnet_ids)
  subnet_id      = var.private_subnet_ids[count.index]
  route_table_id = aws_route_table.hub_private.id
}
