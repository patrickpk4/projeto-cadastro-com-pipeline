# Mostra o endereço público do ALB criado na VPC hub.
output "hub_load_balancer_dns_name" {
  description = "DNS name of the public load balancer in the hub VPC"
  value       = module.network.load_balancer_dns_name
}

# URL HTTP do listener que encaminha as requisições para staging.
output "staging_url" {
  description = "Application URL for the staging EKS cluster"
  value       = "http://${module.network.load_balancer_dns_name}"
}

# URL HTTP do listener dedicado a production.
output "production_url" {
  description = "Application URL for the production EKS cluster"
  value       = "http://${module.network.load_balancer_dns_name}:8080"
}

# Endereço para taguear e publicar a imagem da API no ECR.
output "ecr_repository_url" {
  description = "ECR repository URL for the catalog API image"
  value       = aws_ecr_repository.catalogo_api.repository_url
}

# Nomes dos segredos cujos valores são preenchidos fora do Terraform.
output "mongodb_secrets_manager_names" {
  description = "Secrets Manager secret names for each environment"
  value = {
    for environment, secret in aws_secretsmanager_secret.mongodb :
    environment => secret.name
  }
}
