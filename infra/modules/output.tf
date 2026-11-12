output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_id" {
  value = aws_vpc.public_subnet[*].id
}

output "private_subnet_id" {
  value = aws_vpc.private_subnet[*].id
}

output "vpc_cidr_block" {
  value = aws_vpc.vpc.cidr.block
}
