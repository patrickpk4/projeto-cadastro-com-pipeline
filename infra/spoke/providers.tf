provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = var.owner
      Stack       = "spoke"
      Terraform   = "true"
    }
  }
}
