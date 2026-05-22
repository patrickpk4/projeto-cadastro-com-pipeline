variable "vpc_name" {
  description = "nome da vpc"
  type        = string
}

variable "cidr_vpc" {
  description = "range de ip da vpc"
  type        = string
}

variable "regiao" {
  description = "regiao onde os recursos sao lançados "
  type        = string

}

variable "cidr_private_sub" {
  description = "range de ip da subnet privada "
  type        = set(string)

}

variable "cidr_public_sub" {
  description = "range de ip da subnet privada "
  type        = set(string)

}

variable "azs_subnets" {
  description = " zonas de disponibilidades das subnetes publicas e privadas "
  type        = set(string)

}

variable "project_tags" {
  description = "tags do projeto"
  type        = map(any)

}

#variable "kube_version" {
#  description = "versao do kubernetes"
#  type        = string
#
#}

#variable "kube_name" {
#  description = "nome do cluster kuberntes"
#  type        = string
#
#}

#variable "instance_types" {
#  description = "tipo de instancia "
#  type        = set(string)
#}
#
