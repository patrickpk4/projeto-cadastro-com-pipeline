output "load_balancer_dns_name" {
  description = "DNS name of the public hub load balancer"
  value       = aws_lb.hub.dns_name
}
