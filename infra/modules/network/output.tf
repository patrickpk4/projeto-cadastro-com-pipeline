output "load_balancer_dns_name" {
  description = "DNS name of the shared public hub load balancer"
  value       = aws_lb.hub.dns_name
}

output "load_balancer_security_group_id" {
  description = "Security group used by the shared public hub load balancer"
  value       = aws_security_group.hub_load_balancer.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.hub.id
}

output "public_route_table_id" {
  value = aws_route_table.hub_public.id
}
