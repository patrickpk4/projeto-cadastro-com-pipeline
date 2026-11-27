# Guarda as imagens da API; tags imutáveis evitam sobrescrever builds publicados.
resource "aws_ecr_repository" "catalogo_api" {
  count                = 1
  name                 = "catalogo-api-${var.environment}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "catalogo-api-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Remove camadas órfãs e limita a quantidade de imagens antigas mantidas.
resource "aws_ecr_lifecycle_policy" "catalogo_api" {
  count      = 1
  repository = aws_ecr_repository.catalogo_api[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than seven days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep the most recent 30 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
