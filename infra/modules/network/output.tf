# Retorna o DNS público do ALB.
output "load_balancer_dns_name" {
  description = "DNS name of the public hub load balancer"
  value       = aws_lb.hub.dns_name
}

# ID do SG que controla as conexões de entrada e saída do ALB.
output "load_balancer_security_group_id" {
  description = "Security group used by the public hub load balancer"
  value       = aws_security_group.hub_load_balancer.id
}

# ID do NAT usado pelo roteamento centralizado das VPCs spoke.
output "nat_gateway_id" {
  value = aws_nat_gateway.hub.id
}

# Route table pública à qual são adicionadas as rotas de retorno via TGW.
output "public_route_table_id" {
  value = aws_route_table.hub_public.id
}
