# Define a versão mínima do Terraform e os providers exigidos pelo projeto.
terraform {

  required_version = ">= 1.7.0"

  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = "~> 6.67.0"
    }
  }
}

# Guarda o estado remoto no S3; o workflow fornece os valores específicos do ambiente.
terraform {
  backend "s3" {
    bucket = "aws-bucket"

  }
}

# Configura as chamadas AWS do Terraform na região selecionada.
provider "aws" {
  region = var.aws_region
}
