resource "aws_security_group" "hub_load_balancer" {
  name        = "hub-load-balancer"
  description = "Allow public HTTP traffic to the hub load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Staging HTTP listener"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Production HTTP listener"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "egress" {
    for_each = var.target_vpc_cidr_blocks
    content {
      description = "Forward HTTP to EKS targets"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [egress.value]
    }
  }

  tags = {
    Name      = "hub-load-balancer"
    terraform = "true"
  }
}

resource "aws_lb" "hub" {
  name               = "hub-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.hub_load_balancer.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name      = "hub-public"
    terraform = "true"
  }
}

resource "aws_lb_target_group" "environment" {
  for_each = var.target_group_cluster_names

  name        = "hub-${each.key}"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name                   = "hub-${each.key}"
    "eks:eks-cluster-name" = each.value
    Terraform              = "true"
  }
}

resource "aws_lb_listener" "environment" {
  for_each = {
    staging    = 80
    production = 8080
  }

  load_balancer_arn = aws_lb.hub.arn
  port              = each.value
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.environment[each.key].arn
  }
}
