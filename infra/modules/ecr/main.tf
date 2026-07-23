# ---------------------------------------------------------------------------
# ECR: backend ve nginx icin iki repository.
# Lifecycle policy ile son 10 imaj disindakiler temizlenir (depolama maliyeti).
# ---------------------------------------------------------------------------

variable "project" {
  type = string
}

locals {
  repos = ["backend", "nginx"]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.repos)

  name                 = "${var.project}/${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Son 10 imaji tut, gerisini sil"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "backend_repo_url" {
  value = aws_ecr_repository.this["backend"].repository_url
}

output "nginx_repo_url" {
  value = aws_ecr_repository.this["nginx"].repository_url
}

output "backend_repo_name" {
  value = aws_ecr_repository.this["backend"].name
}

output "nginx_repo_name" {
  value = aws_ecr_repository.this["nginx"].name
}
