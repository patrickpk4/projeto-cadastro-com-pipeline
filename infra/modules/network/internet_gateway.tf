# Conecta a VPC hub à internet.
resource "aws_internet_gateway" "hub" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "igw-hub"
    terraform = "true"
  }
}

# Guarda as rotas usadas pelas subnets públicas do hub.
resource "aws_route_table" "hub_public" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "rt-hub-public"
    terraform = "true"
  }
}

# Envia o tráfego público não local para o Internet Gateway.
resource "aws_route" "hub_public_internet" {
  route_table_id         = aws_route_table.hub_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.hub.id
}

# Aplica a route table pública a cada subnet pública do hub.
resource "aws_route_table_association" "hub_public" {
  count          = length(var.public_subnet_ids)
  subnet_id      = var.public_subnet_ids[count.index]
  route_table_id = aws_route_table.hub_public.id
}

# Reserva o IP público fixo usado pelo NAT Gateway.
resource "aws_eip" "hub_nat" {
  domain = "vpc"

  tags = {
    Name      = "eip-nat-hub"
    terraform = "true"
  }
}

# Cria o NAT Gateway em uma subnet pública para permitir saída à internet.
resource "aws_nat_gateway" "hub" {
  allocation_id = aws_eip.hub_nat.id
  subnet_id     = var.public_subnet_ids[0]

  tags = {
    Name      = "natgw-hub"
    terraform = "true"
  }

  depends_on = [aws_route_table_association.hub_public]
}
