# Cria mapas estáveis para associar route tables a cada subnet.
locals {
  # Gera uma rota blackhole de cada VPC spoke para cada outra spoke.
  spoke_isolation_routes = {
    for route in flatten([
      for source_vpc in keys(var.spoke_vpcs) : [
        for destination_vpc, destination in var.spoke_vpcs : {
          key                    = "${source_vpc}-${destination_vpc}"
          source_vpc             = source_vpc
          destination_cidr_block = destination.cidr_block
        } if source_vpc != destination_vpc
      ]
    ]) : route.key => route
  }

  # Mapeia as subnets privadas para associá-las à route table da VPC de origem.
  spoke_private_subnets = {
    for subnet in flatten([
      for name, vpc in var.spoke_vpcs : [
        for index, subnet_id in vpc.private_subnet_ids : {
          key       = "${name}-${index}"
          vpc_name  = name
          subnet_id = subnet_id
        }
      ]
    ]) : subnet.key => subnet
  }

  # Cria chaves estáveis para associar as subnets de trânsito do hub.
  hub_transit_subnets = {
    for index, subnet_id in var.hub_transit_subnet_ids :
    "hub-${index}" => subnet_id
  }
}

# Cria o Transit Gateway que centraliza a saída para a internet.
resource "aws_ec2_transit_gateway" "central_egress" {
  description                        = "Central egress for staging and production"
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  security_group_referencing_support = "enable"

  tags = {
    Name      = "central-egress"
    Terraform = "true"
  }
}

# Conecta ao Transit Gateway as subnets de trânsito privadas do hub.
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  subnet_ids         = var.hub_transit_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id
  vpc_id             = var.hub_vpc_id

  tags = {
    Name      = "hub-egress"
    Terraform = "true"
  }
}

# Conecta cada VPC privada ao mesmo Transit Gateway.
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  for_each = var.spoke_vpcs

  subnet_ids         = each.value.private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id
  vpc_id             = each.value.vpc_id

  tags = {
    Name      = "${each.key}-egress"
    Terraform = "true"
  }
}

# Define as rotas que o hub usa para responder às VPCs privadas.
resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id

  tags = {
    Name      = "hub-egress"
    Terraform = "true"
  }
}

# Define uma tabela de rotas por VPC privada.
resource "aws_ec2_transit_gateway_route_table" "spoke" {
  for_each = var.spoke_vpcs

  transit_gateway_id = aws_ec2_transit_gateway.central_egress.id

  tags = {
    Name      = "${each.key}-egress"
    Terraform = "true"
  }
}

# Associa o hub à tabela de rotas que conhece as VPCs privadas.
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

# Associa cada VPC privada à tabela de saída pelo hub.
resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  for_each = var.spoke_vpcs

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[each.key].id
}

# Envia o tráfego externo das VPCs privadas para o anexo do hub.
resource "aws_ec2_transit_gateway_route" "spoke_default" {
  for_each = var.spoke_vpcs

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[each.key].id
}

# Bloqueia o tráfego direto entre staging e production.
resource "aws_ec2_transit_gateway_route" "spoke_isolation" {
  for_each = local.spoke_isolation_routes

  blackhole                      = true
  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[each.value.source_vpc].id
}

# Permite que o hub encontre a VPC privada de destino.
resource "aws_ec2_transit_gateway_route" "hub_to_spoke" {
  for_each = var.spoke_vpcs

  destination_cidr_block         = each.value.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

# Cria uma route table privada para cada VPC conectada.
resource "aws_route_table" "spoke_private" {
  for_each = var.spoke_vpcs

  vpc_id = each.value.vpc_id

  tags = {
    Name      = "${each.key}-private"
    Terraform = "true"
  }
}

# Envia a saída padrão das subnets privadas ao Transit Gateway.
resource "aws_route" "spoke_default" {
  for_each = var.spoke_vpcs

  route_table_id         = aws_route_table.spoke_private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.central_egress.id
}

# Associa cada subnet privada à route table da sua VPC.
resource "aws_route_table_association" "spoke_private" {
  for_each = local.spoke_private_subnets

  subnet_id      = each.value.subnet_id
  route_table_id = aws_route_table.spoke_private[each.value.vpc_name].id
}

# Cria a route table das subnets de trânsito do hub.
resource "aws_route_table" "hub_transit" {
  vpc_id = var.hub_vpc_id

  tags = {
    Name      = "hub-transit"
    Terraform = "true"
  }
}

# Encaminha o tráfego recebido pelo hub para o NAT Gateway.
resource "aws_route" "hub_transit_default" {
  route_table_id         = aws_route_table.hub_transit.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.hub_nat_gateway_id
}

# Associa as subnets de trânsito do hub à route table central.
resource "aws_route_table_association" "hub_transit" {
  for_each = local.hub_transit_subnets

  subnet_id      = each.value
  route_table_id = aws_route_table.hub_transit.id
}

# Devolve pelo Transit Gateway as respostas destinadas às VPCs privadas.
resource "aws_route" "hub_nat_return" {
  for_each = var.spoke_vpcs

  route_table_id         = var.hub_public_route_table_id
  destination_cidr_block = each.value.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.central_egress.id
}
