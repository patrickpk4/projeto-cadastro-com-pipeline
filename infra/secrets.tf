# Cria somente os metadados; os valores são inseridos diretamente no Secrets Manager.
resource "aws_secretsmanager_secret" "mongodb" {
  for_each = toset(["staging", "production"])

  name        = "projeto-cadastro/${each.key}/mongodb"
  description = "MongoDB credentials for the ${each.key} EKS cluster"

  tags = {
    Environment = each.key
    Terraform   = "true"
  }
}
