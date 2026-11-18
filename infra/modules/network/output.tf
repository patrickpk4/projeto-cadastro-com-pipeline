output "load_balancer_dns_name" {
  description = "DNS name of the public hub load balancer"
  value       = aws_lb.hub.dns_name
}

output "nat_gateway_id" {
  value = aws_nat_gateway.hub.id
}

output "public_route_table_id" {
  value = aws_route_table.hub_public.id
}
