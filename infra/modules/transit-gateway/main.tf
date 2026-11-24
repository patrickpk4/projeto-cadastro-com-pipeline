resource "aws_ec2_transit_gateway" "central_egress" {
  description                        = "Shared hub Transit Gateway for staging and production"
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  security_group_referencing_support = "enable"

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

resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id

  tags = {
    Name      = "hub-egress"
    Terraform = "true"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}
