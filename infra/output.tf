# Mostra o endereço público do ALB criado na VPC hub.
output "hub_load_balancer_dns_name" {
  description = "DNS name of the public load balancer in the hub VPC"
  value       = module.network.load_balancer_dns_name
}

output "staging_url" {
  description = "Application URL for the staging EKS cluster"
  value       = "http://${module.network.load_balancer_dns_name}"
}

output "production_url" {
  description = "Application URL for the production EKS cluster"
  value       = "http://${module.network.load_balancer_dns_name}:8080"
}
