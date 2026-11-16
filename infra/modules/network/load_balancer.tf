resource "aws_security_group" "hub_load_balancer" {
  name        = "hub-load-balancer"
  description = "Allow public HTTP traffic to the hub load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_lb_target_group" "hub_http" {
  name        = "hub-http"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name      = "hub-http"
    terraform = "true"
  }
}

resource "aws_lb_listener" "hub_http" {
  load_balancer_arn = aws_lb.hub.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hub_http.arn
  }
}
