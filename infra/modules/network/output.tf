# Retorna o DNS público do ALB.
output "load_balancer_dns_name" {
  description = "DNS name of the public hub load balancer"
  value       = aws_lb.hub.dns_name
}

output "load_balancer_security_group_id" {
  description = "Security group used by the public hub load balancer"
  value       = aws_security_group.hub_load_balancer.id
}

# Retorna o ID do NAT usado pelo Transit Gateway.
output "nat_gateway_id" {
  value = aws_nat_gateway.hub.id
}

# Retorna a route table pública usada para o tráfego de retorno.
output "public_route_table_id" {
  value = aws_route_table.hub_public.id
}
