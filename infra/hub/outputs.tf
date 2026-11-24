output "load_balancer_dns_name" {
  description = "DNS name of the shared hub load balancer"
  value       = module.network[0].load_balancer_dns_name
}

output "application_url" {
  description = "Application URL is configured by each spoke"
  value       = null
}

output "ecr_repository_url" {
  description = "ECR repositories belong to the spokes"
  value       = null
}

output "cluster_name" {
  description = "EKS clusters belong to the spokes"
  value       = null
}

output "vpc_id" {
  description = "VPC ID of the shared hub"
  value       = module.vpc.vpc_id
}

output "hub_load_balancer_dns_name" {
  description = "DNS name of the shared public hub load balancer"
  value       = module.network[0].load_balancer_dns_name
}

output "hub_load_balancer_security_group_id" {
  description = "Security group used by the shared hub load balancer"
  value       = module.network[0].load_balancer_security_group_id
}

output "hub_public_route_table_id" {
  description = "Public route table in the shared hub VPC"
  value       = module.network[0].public_route_table_id
}

output "hub_attachment_id" {
  description = "Transit Gateway attachment for the shared hub VPC"
  value       = module.transit_gateway[0].hub_attachment_id
}

output "hub_route_table_id" {
  description = "Transit Gateway route table for routes from the hub"
  value       = module.transit_gateway[0].hub_route_table_id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID shared by the environment VPCs"
  value       = module.transit_gateway[0].transit_gateway_id
}
