# ID usado por outros recursos para identificar o Transit Gateway central.
output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.central_egress.id
}
