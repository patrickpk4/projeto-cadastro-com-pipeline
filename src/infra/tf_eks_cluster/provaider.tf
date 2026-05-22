terraform {

  required_version = ">= 1.7.0"

  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = "~>6.41.0"
    }
  }
}

terraform {
  backend "s3" {

  }
}


provider "aws" {
  region = var.regiao
}