# ---------------------------------------------------------------------------
# Secrets: DB parolasi ve JWT secret'i uretir ve Secrets Manager'da saklar.
# Ayni db_password hem RDS master password hem de backend container'in
# POSTGRES_PASSWORD'u olarak kullanilir (tek kaynak).
# ---------------------------------------------------------------------------

variable "project" {
  type = string
}

resource "random_password" "db" {
  length  = 24
  special = false # RDS bazi ozel karakterleri kabul etmez; alfanumerik guvenli
}

resource "random_password" "jwt" {
  length  = 48
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project}/db-password"
  recovery_window_in_days = 0 # ogrenme ortami: hemen silinebilsin
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.project}/jwt-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result
}

# ECS task def secrets bloguna verilecek ARN'ler
output "db_password_secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt.arn
}

# RDS master password icin (sensitive)
output "db_password_value" {
  value     = random_password.db.result
  sensitive = true
}
