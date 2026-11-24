output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.central_egress.id
}

output "hub_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.hub.id
}

output "hub_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.hub.id
}
