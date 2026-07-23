# ---------------------------------------------------------------------------
# RDS PostgreSQL - maliyet-minimal: db.t3.micro, single-AZ, 20GB gp3.
# Private subnet'lerde, publicly_accessible=false. Sadece task_sg :5432 erisir.
# ---------------------------------------------------------------------------

variable "project" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "task_security_group_id" {
  description = "ECS task SG - RDS'e 5432'den erisecek tek kaynak"
  type        = string
}
variable "db_name" {
  type    = string
  default = "taskdb"
}
variable "db_username" {
  type    = string
  default = "taskuser"
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project}-db-subnets" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS - sadece ECS task'tan 5432"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS task"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.task_security_group_id]
  }

  # RDS'in disari cikmasina gerek yok ama TF egress bos birakmayi sever
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-rds-sg" }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  skip_final_snapshot     = true # ogrenme ortami: destroy kolay olsun
  deletion_protection     = false
  apply_immediately       = true

  tags = { Name = "${var.project}-postgres" }
}

output "address" {
  description = "RDS endpoint hostname (port haric)"
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
