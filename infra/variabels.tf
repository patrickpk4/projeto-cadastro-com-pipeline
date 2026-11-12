variable "aws_region" {
  type    = string
  default = "us-east-1"
}
# armazena a configuração de múltiplos blocos VPC
variable "vpcs" {
  type = map(object({
    cidr_block           = string
    availability_zones   = list(string)
    public_subnets_cidr  = list(string)
    private_subnets_cidr = list(string)
  }))
}