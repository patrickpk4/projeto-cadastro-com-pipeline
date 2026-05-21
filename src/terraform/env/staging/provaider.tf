terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.40.0"
    }
  }
}

terraform {
  backend "s3" {

  }
}


provider "aws" {
  region = "us-east-1"
}