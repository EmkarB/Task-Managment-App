variable "region" {
  description = "AWS region (Ispanya = eu-south-2)"
  type        = string
  default     = "eu-south-2"
}

variable "project" {
  description = "Proje adi (kaynak isimlendirme onki)"
  type        = string
  default     = "taskapp"
}

variable "azs" {
  description = "2 availability zone (region'a uygun olmali)"
  type        = list(string)
  default     = ["eu-south-2a", "eu-south-2b"]
}

variable "github_repo" {
  description = "GitHub OIDC guveni: owner/repo"
  type        = string
  default     = "EmkarB/Task-Managment-App"
}

variable "github_branch" {
  description = "Deploy'a izinli branch"
  type        = string
  default     = "main"
}

# Ilk apply icin placeholder imajlar. Gercek imajlar CI ile :sha olarak gelir.
# Task def CI tarafindan yonetildigi icin (ignore_changes) bu degerler
# yalnizca ilk kurulumdaki task def revizyonunda kullanilir.
variable "backend_image" {
  description = "Backend container imaji (ilk apply icin)"
  type        = string
  default     = "public.ecr.aws/docker/library/busybox:latest"
}

variable "nginx_image" {
  description = "Nginx container imaji (ilk apply icin)"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
