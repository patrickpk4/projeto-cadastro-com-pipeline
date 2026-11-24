variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "transit_subnet_ids" {
  type = list(string)
}

variable "target_vpc_cidr_blocks" {
  type = list(string)
}

variable "target_group_cluster_names" {
  type = map(string)
}
