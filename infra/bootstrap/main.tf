# ---------------------------------------------------------------------------
# Bootstrap: Terraform remote state altyapisi (S3 + DynamoDB lock)
#
# Bu, ana konfigurasyondan ONCE bir defa uygulanir. State bucket'i kendi
# state'ini tutamaz (tavuk-yumurta), o yuzden bu modul LOCAL state kullanir
# ve olusturdugu bucket/tablo ana konfigurasyonun backend.tf'i tarafindan kullanilir.
#
# Kullanim:
#   cd infra/bootstrap
#   terraform init && terraform apply
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "AWS region (Ispanya = eu-south-2)"
  type        = string
  default     = "eu-south-2"
}

variable "project" {
  description = "Proje adi (kaynak isimlendirme icin)"
  type        = string
  default     = "taskapp"
}

variable "state_bucket_name" {
  description = "Terraform state icin S3 bucket adi (global benzersiz olmali)"
  type        = string
  # Ornek: "taskapp-tfstate-emkarb-eucentral1" - terraform.tfvars ile override edin
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State locking icin DynamoDB tablosu
resource "aws_dynamodb_table" "lock" {
  name         = "${var.project}-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  description = "backend.tf icinde kullanilacak bucket adi"
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "backend.tf icinde kullanilacak DynamoDB tablo adi"
  value       = aws_dynamodb_table.lock.name
}
