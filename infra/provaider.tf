terraform {

  required_version = ">= 1.7.0"

  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = "~> 6.66.0"
    }
  }
}

terraform {
  backend "s3" { 
    bucket = "backend-terraform-aws" 
  }
}


provider "aws" {
  region = var.regiao
}