output "load_balancer_dns_name" {
  description = "DNS name of the shared hub load balancer"
  value       = data.terraform_remote_state.hub.outputs.hub_load_balancer_dns_name
}

output "application_url" {
  description = "Application URL for the selected environment"
  value       = "http://${data.terraform_remote_state.hub.outputs.hub_load_balancer_dns_name}:${var.environment == "staging" ? 80 : 8080}"
}

output "ecr_repository_url" {
  description = "Environment-specific ECR repository URL for the catalog API image"
  value       = aws_ecr_repository.catalogo_api[0].repository_url
}

output "cluster_name" {
  description = "Name of the environment-specific EKS cluster"
  value       = module.eks[0].cluster_name
}

output "vpc_id" {
  description = "VPC ID for the selected stack"
  value       = module.vpc.vpc_id
}

output "hub_load_balancer_dns_name" {
  description = "DNS name of the shared hub load balancer"
  value       = data.terraform_remote_state.hub.outputs.hub_load_balancer_dns_name
}

output "hub_load_balancer_security_group_id" {
  description = "Security group ID used by the shared hub load balancer"
  value       = data.terraform_remote_state.hub.outputs.hub_load_balancer_security_group_id
}

output "hub_public_route_table_id" {
  description = "Public route table in the shared hub VPC"
  value       = data.terraform_remote_state.hub.outputs.hub_public_route_table_id
}

output "hub_attachment_id" {
  description = "Transit Gateway attachment for the shared hub VPC"
  value       = data.terraform_remote_state.hub.outputs.hub_attachment_id
}

output "hub_route_table_id" {
  description = "Transit Gateway route table for routes from the hub"
  value       = data.terraform_remote_state.hub.outputs.hub_route_table_id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID shared by the environment VPCs"
  value       = data.terraform_remote_state.hub.outputs.transit_gateway_id
}
