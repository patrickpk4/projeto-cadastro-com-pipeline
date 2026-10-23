terraform {

  required_version = ">= 1.7.0"

  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = "~> 6.69.1"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "aws-bucket"

  }
}


provider "aws" {
  region = var.regiao
}
