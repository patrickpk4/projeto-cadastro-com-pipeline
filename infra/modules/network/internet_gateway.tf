resource "aws_internet_gateway" "hub" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "igw-hub"
    terraform = "true"
  }
}

resource "aws_route_table" "hub_public" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "rt-hub-public"
    terraform = "true"
  }
}

resource "aws_route" "hub_public_internet" {
  route_table_id         = aws_route_table.hub_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.hub.id
}

resource "aws_route_table_association" "hub_public" {
  count          = length(var.public_subnet_ids)
  subnet_id      = var.public_subnet_ids[count.index]
  route_table_id = aws_route_table.hub_public.id
}

resource "aws_eip" "hub_nat" {
  domain = "vpc"

  tags = {
    Name      = "eip-nat-hub"
    terraform = "true"
  }
}

resource "aws_nat_gateway" "hub" {
  allocation_id = aws_eip.hub_nat.id
  subnet_id     = var.public_subnet_ids[0]

  tags = {
    Name      = "natgw-hub"
    terraform = "true"
  }

  depends_on = [aws_route_table_association.hub_public]
}

resource "aws_route_table" "hub_transit" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "rt-hub-transit"
    terraform = "true"
  }
}

resource "aws_route" "hub_transit_default" {
  route_table_id         = aws_route_table.hub_transit.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.hub.id
}

resource "aws_route_table_association" "hub_transit" {
  count          = length(var.transit_subnet_ids)
  subnet_id      = var.transit_subnet_ids[count.index]
  route_table_id = aws_route_table.hub_transit.id
}
