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
    bucket = "backend-013644997946-us-east-1-an" 
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}


provider "aws" {
  region = var.regiao
}