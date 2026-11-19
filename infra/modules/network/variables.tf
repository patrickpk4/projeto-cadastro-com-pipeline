# ID da VPC hub onde ficam os recursos públicos de rede.
variable "vpc_id" {
  type = string
}

# IDs das subnets públicas usadas pelo IGW, NAT e ALB.
variable "public_subnet_ids" {
  type = list(string)
}

variable "target_vpc_cidr_blocks" {
  description = "CIDRs das VPCs dos clusters que recebem tráfego do ALB"
  type        = list(string)
}

variable "target_group_cluster_names" {
  description = "Nomes dos clusters EKS associados aos target groups por ambiente"
  type        = map(string)
}
