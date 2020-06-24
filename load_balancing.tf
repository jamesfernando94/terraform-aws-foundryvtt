locals {
  foundry_port = 30000
}

resource "aws_security_group" "foundry_load_balancer" {
  name_prefix            = "foundry-lb-sg-${terraform.workspace}"
  revoke_rules_on_delete = true
  tags                   = local.tags_rendered
  vpc_id                 = aws_vpc.foundry.id

  depends_on = [aws_internet_gateway.foundry]
}

resource "aws_security_group_rule" "lb_allow_inbound_80" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.foundry_load_balancer.id
  to_port           = local.foundry_port
  type              = "ingress"
}

resource "aws_security_group_rule" "lb_allow_inbound_443" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.foundry_load_balancer.id
  to_port           = local.foundry_port
  type              = "ingress"
}

resource "aws_security_group_rule" "lb_allow_foundry_port_egress" {
  from_port                = local.foundry_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.foundry_load_balancer.id
  source_security_group_id = aws_security_group.foundry_server.id
  to_port                  = local.foundry_port
  type                     = "egress"
}

resource "aws_lb" "foundry_server" {
  name               = "foundry-server-${terraform.workspace}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.foundry_load_balancer.id]
  subnets            = [aws_subnet.foundry_public_first.id, aws_subnet.foundry_public_second.id]
  tags               = local.tags_rendered
}

resource "aws_lb_target_group" "lb_foundry_server_http" {
  name     = "${aws_lb.foundry_server.name}-http-tg"
  port     = aws_security_group_rule.lb_allow_inbound_80.to_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.foundry.id

  health_check {
    healthy_threshold = 2
    matcher = "200-299,302"
    path = "/"
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group" "lb_foundry_server_https" {
  name     = "${aws_lb.foundry_server.name}-https-tg"
  port     = aws_security_group_rule.lb_allow_inbound_443.to_port
  protocol = "HTTPS"
  vpc_id   = aws_vpc.foundry.id

  health_check {
    healthy_threshold = 2
    matcher = "200-299,302"
    path = "/"
    protocol = "HTTPS"
  }
}

resource "aws_lb_listener" "foundry_server_http" {
  load_balancer_arn = aws_lb.foundry_server.arn
  port              = aws_security_group_rule.lb_allow_inbound_80.from_port
  protocol          = aws_lb_target_group.lb_foundry_server_http.protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_foundry_server_http.arn
  }
}

# resource "aws_lb_listener" "foundry_server_https" {
#   load_balancer_arn = aws_lb.foundry_server.arn
#   port              = aws_security_group_rule.lb_allow_inbound_443.from_port
#   protocol          = aws_lb_target_group.foundry_server_https.protocol
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.foundry_server_https.arn
#   }
# }

output lb_arn {
  value = aws_lb.foundry_server.arn
}

output lb_dns_name {
  value = aws_lb.foundry_server.dns_name
}

output lb_zone_id {
  value = aws_lb.foundry_server.zone_id
}

output target_group_http_arn {
  value = aws_lb_target_group.lb_foundry_server_http.arn
}

output target_group_http_name {
  value = aws_lb_target_group.lb_foundry_server_http.name
}

output target_group_https_arn {
  value = aws_lb_target_group.lb_foundry_server_https.arn
}

output target_group_https_name {
  value = aws_lb_target_group.lb_foundry_server_https.name
}