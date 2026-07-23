# ---------------------------------------------------------------------------
# ALB - public, sadece HTTP :80. Hedef: nginx container (:80), target_type=ip.
# Health check: /healthz (nginx'te backend'e dokunmayan hafif 200).
# ---------------------------------------------------------------------------

variable "project" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "alb_security_group_id" {
  type = string
}

resource "aws_lb" "this" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  idle_timeout = 300 # websocket'ler icin biraz genis

  tags = { Name = "${var.project}-alb" }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate/awsvpc zorunlu

  health_check {
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  # socket.io tek task'ta stickiness gerektirmez; ileride >1 task icin acilir.
  # stickiness { type = "lb_cookie" enabled = true }

  tags = { Name = "${var.project}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}
