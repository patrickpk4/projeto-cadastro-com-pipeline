terraform {

  required_version = ">= 1.7.0"

  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = ">= 6.59.0, < 7.0.0"
    }
  }
}

terraform {
  backend "s3" {bucket = "backend-013644997946-us-east-1-an"}
}


provider "aws" {
  region = var.regiao
}