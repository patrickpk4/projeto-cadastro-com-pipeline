resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  count = 1

  subnet_ids         = module.vpc.private_subnet_ids
  transit_gateway_id = data.terraform_remote_state.hub.outputs.transit_gateway_id
  vpc_id             = module.vpc.vpc_id

  tags = {
    Name        = "${var.environment}-egress"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  count = 1

  transit_gateway_id = data.terraform_remote_state.hub.outputs.transit_gateway_id

  tags = {
    Name        = "${var.environment}-egress"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  count = 1

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[0].id
}

resource "aws_ec2_transit_gateway_route" "spoke_default" {
  count = 1

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = data.terraform_remote_state.hub.outputs.hub_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[0].id
}

resource "aws_ec2_transit_gateway_route" "spoke_isolation" {
  for_each = toset(var.peer_vpc_cidrs)

  blackhole                      = true
  destination_cidr_block         = each.value
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[0].id
}

resource "aws_ec2_transit_gateway_route" "hub_to_spoke" {
  count = 1

  destination_cidr_block         = var.vpc.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[0].id
  transit_gateway_route_table_id = data.terraform_remote_state.hub.outputs.hub_route_table_id
}

resource "aws_route_table" "spoke_private" {
  count = 1

  vpc_id = module.vpc.vpc_id

  tags = {
    Name        = "${var.environment}-private"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route" "spoke_default" {
  count = 1

  route_table_id         = aws_route_table.spoke_private[0].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = data.terraform_remote_state.hub.outputs.transit_gateway_id
}

resource "aws_route_table_association" "spoke_private" {
  count = length(module.vpc.private_subnet_ids)

  subnet_id      = module.vpc.private_subnet_ids[count.index]
  route_table_id = aws_route_table.spoke_private[0].id
}

resource "aws_route" "hub_nat_return" {
  count = 1

  route_table_id         = data.terraform_remote_state.hub.outputs.hub_public_route_table_id
  destination_cidr_block = var.vpc.cidr_block
  transit_gateway_id     = data.terraform_remote_state.hub.outputs.transit_gateway_id
}
