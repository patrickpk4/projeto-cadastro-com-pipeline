provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "hub"
      Owner       = var.owner
      Stack       = "hub"
      Terraform   = "true"
    }
  }
}
