variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnets_cidr" {
  type = list(string)
}

variable "private_subnets_cidr" {
  type = list(string)
}