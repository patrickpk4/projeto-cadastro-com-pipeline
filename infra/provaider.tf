# Define a versão mínima do Terraform e os providers usados.
terraform {

  required_version = ">= 1.7.0"

  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = "~> 6.67.0"
    }
  }
}

# Guarda o estado remoto no S3; o workflow informa o bucket e a região.
terraform {
  backend "s3" {
    bucket = "aws-bucket"

  }
}

# Configura o provider AWS na região escolhida.
provider "aws" {
  region = var.aws_region
}
