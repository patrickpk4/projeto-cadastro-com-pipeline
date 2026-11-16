output "hub_load_balancer_dns_name" {
  description = "DNS name of the public load balancer in the hub VPC"
  value       = module.network.load_balancer_dns_name
}
