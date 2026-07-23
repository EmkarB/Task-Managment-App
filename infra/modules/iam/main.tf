# ---------------------------------------------------------------------------
# IAM:
#  - ECS task execution role (imaj cekme, log yazma, secret okuma)
#  - ECS task role (uygulamanin kendi AWS izinleri - simdilik bos)
#  - GitHub OIDC provider + deploy role (statik key olmadan CI/CD)
# ---------------------------------------------------------------------------

variable "project" {
  type = string
}

variable "github_repo" {
  description = "OIDC guveni icin: owner/repo (or. EmkarB/Task-Managment-App)"
  type        = string
}

variable "github_branch" {
  description = "Deploy'a izinli branch"
  type        = string
  default     = "main"
}

variable "secret_arns" {
  description = "Execution role'un okuyabilecegi Secrets Manager ARN'leri"
  type        = list(string)
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ======================= ECS Task Execution Role =======================
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.project}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# Imaj cekme + log yazma (AWS yonetilen politika)
resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager okuma (container secrets injection icin)
data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.secret_arns
  }
  # KMS default key ile sifreliyse decrypt gerekir; SM default kullaniyorsa da zararsiz
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${var.project}-execution-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

# ======================= ECS Task Role =======================
# Uygulama kodu su an AWS API cagirmiyor; rol bos ama ileriye donuk hazir.
resource "aws_iam_role" "task" {
  name               = "${var.project}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# ======================= GitHub OIDC + Deploy Role =======================
# OIDC provider hesapta zaten var (baska bir kurulumdan). Yeniden yaratmak yerine
# mevcut olani referansla; boylece hesapta tek provider kalir.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${var.project}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

# CI/CD icin gerekli izinler: ECR push, ECS deploy, PassRole
data "aws_iam_policy_document" "github_deploy" {
  # ECR login (hesap capinda gerekli)
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR push/pull (repo bazli)
  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.project}/*"
    ]
  }

  # ECS: task def kaydet + servisi guncelle + durum oku
  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = ["*"]
  }

  # ECS'in yeni task def'i rollerle calistirabilmesi icin PassRole
  statement {
    sid       = "PassEcsRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${var.project}-github-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
