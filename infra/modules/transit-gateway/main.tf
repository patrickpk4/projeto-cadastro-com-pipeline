locals {
  spoke_private_subnets = {
    for subnet in flatten([
      for name, vpc in var.spoke_vpcs : [
        for index, subnet_id in vpc.private_subnet_ids : {
          key       = "${name}-${index}"
          vpc_name  = name
          subnet_id = subnet_id
        }
      ]
    ]) : subnet.key => subnet
  }

  hub_transit_subnets = {
    for index, subnet_id in var.hub_transit_subnet_ids :
    "hub-${index}" => subnet_id
  }
}

resource "aws_ec2_transit_gateway" "central_egress" {
  description                     = "Central egress for staging and production"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name      = "central-egress"
    Terraform = "true"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  subnet_ids         = var.hub_transit_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id
  vpc_id             = var.hub_vpc_id

  tags = {
    Name      = "hub-egress"
    Terraform = "true"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  for_each = var.spoke_vpcs

  subnet_ids         = each.value.private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id
  vpc_id             = each.value.vpc_id

  tags = {
    Name      = "${each.key}-egress"
    Terraform = "true"
  }
}

resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id

  tags = {
    Name      = "hub-egress"
    Terraform = "true"
  }
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id

  tags = {
    Name      = "spokes-egress"
    Terraform = "true"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  for_each = var.spoke_vpcs

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route" "spoke_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route" "spoke_isolation" {
  for_each = var.spoke_vpcs

  blackhole                      = true
  destination_cidr_block         = each.value.cidr_block
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route" "hub_to_spoke" {
  for_each = var.spoke_vpcs

  destination_cidr_block         = each.value.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_route_table" "spoke_private" {
  for_each = var.spoke_vpcs

  vpc_id = each.value.vpc_id

  tags = {
    Name      = "${each.key}-private"
    Terraform = "true"
  }
}

resource "aws_route" "spoke_default" {
  for_each = var.spoke_vpcs

  route_table_id         = aws_route_table.spoke_private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.central_egress.id
}

resource "aws_route_table_association" "spoke_private" {
  for_each = local.spoke_private_subnets

  subnet_id      = each.value.subnet_id
  route_table_id = aws_route_table.spoke_private[each.value.vpc_name].id
}

resource "aws_route_table" "hub_transit" {
  vpc_id = var.hub_vpc_id

  tags = {
    Name      = "hub-transit"
    Terraform = "true"
  }
}

resource "aws_route" "hub_transit_default" {
  route_table_id         = aws_route_table.hub_transit.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.hub_nat_gateway_id
}

resource "aws_route_table_association" "hub_transit" {
  for_each = local.hub_transit_subnets

  subnet_id      = each.value
  route_table_id = aws_route_table.hub_transit.id
}

resource "aws_route" "hub_nat_return" {
  for_each = var.spoke_vpcs

  route_table_id         = var.hub_public_route_table_id
  destination_cidr_block = each.value.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.central_egress.id
}
