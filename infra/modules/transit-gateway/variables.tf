variable "hub_vpc_id" {
  type = string
}

variable "hub_transit_subnet_ids" {
  type = list(string)
}

variable "hub_nat_gateway_id" {
  type = string
}

variable "hub_public_route_table_id" {
  type = string
}

variable "spoke_vpcs" {
  type = map(object({
    vpc_id             = string
    cidr_block         = string
    private_subnet_ids = list(string)
  }))
}
