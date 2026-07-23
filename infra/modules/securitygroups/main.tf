# ---------------------------------------------------------------------------
# Security Groups - ayri modul, cunku hem ALB, RDS hem ECS bunlara baglanir.
# Ayri tutmak rds<->ecs modul dongusunu kirar.
#
#   alb_sg  : internetten :80
#   task_sg : ALB'den :80 (backend/mongo/redis loopback, disari kapali)
# ---------------------------------------------------------------------------

variable "project" {
  type = string
}
variable "vpc_id" {
  type = string
}

resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB - internetten HTTP"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
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

  tags = { Name = "${var.project}-alb-sg" }
}

resource "aws_security_group" "task" {
  name        = "${var.project}-task-sg"
  description = "Fargate task - sadece ALB'den :80"
  vpc_id      = var.vpc_id

  ingress {
    description     = "nginx from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress acik: ECR pull, Secrets Manager, CloudWatch Logs, RDS:5432
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-task-sg" }
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "task_sg_id" {
  value = aws_security_group.task.id
}
