variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "owner" {
  type    = string
  default = "lab"
}

variable "peer_vpc_cidrs" {
  type = list(string)
}

variable "cluster_names" {
  type = map(string)
}

variable "vpc" {
  type = object({
    cidr_block           = string
    availability_zones   = list(string)
    public_subnets_cidr  = list(string)
    private_subnets_cidr = list(string)
    transit_subnets_cidr = list(string)
  })

  validation {
    condition = (
      length(var.vpc.availability_zones) >= 2 &&
      (length(var.vpc.public_subnets_cidr) == 0 || length(var.vpc.public_subnets_cidr) == length(var.vpc.availability_zones)) &&
      (length(var.vpc.private_subnets_cidr) == 0 || length(var.vpc.private_subnets_cidr) == length(var.vpc.availability_zones)) &&
      (length(var.vpc.transit_subnets_cidr) == 0 || length(var.vpc.transit_subnets_cidr) == length(var.vpc.availability_zones))
    )
    error_message = "Each non-empty subnet list must contain one subnet per availability zone, with at least two zones."
  }
}
