variable "project" {
  type = string
}
variable "region" {
  type = string
}
variable "public_subnet_ids" {
  description = "Task'lar public subnet'te calisir (NAT yok, public IP ile ECR pull)"
  type        = list(string)
}
variable "task_security_group_id" {
  type = string
}
variable "target_group_arn" {
  type = string
}
variable "execution_role_arn" {
  type = string
}
variable "task_role_arn" {
  type = string
}

# Imajlar (ilk apply icin placeholder :latest; CI :sha ile gunceller)
variable "backend_image" {
  type = string
}
variable "nginx_image" {
  type = string
}

# Backend env
variable "postgres_host" {
  type = string
}
variable "postgres_port" {
  type    = number
  default = 5432
}
variable "postgres_db" {
  type    = string
  default = "taskdb"
}
variable "postgres_user" {
  type    = string
  default = "taskuser"
}

# Secrets Manager ARN'leri
variable "db_password_secret_arn" {
  type = string
}
variable "jwt_secret_arn" {
  type = string
}

variable "task_cpu" {
  type    = number
  default = 512
}
variable "task_memory" {
  type    = number
  default = 1024
}
