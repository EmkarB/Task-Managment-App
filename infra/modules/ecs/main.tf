# ---------------------------------------------------------------------------
# ECS Fargate - tek servis, tek task, desired_count=1.
# 4 container: nginx (ALB target) + backend + mongo + redis (loopback sidecar).
#
# NEDEN TEK TASK: backend websocket state'i bellek-ici (Redis adapter yok);
# init_postgres() her acilista create_all yapar (Alembic yok). Coklu task bozar.
#
# VERI: mongo + redis EPHEMERAL (EFS yok). Her deploy/restart'ta veri sifirlanir.
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = "${var.project}-cluster"
  setting {
    name  = "containerInsights"
    value = "disabled" # maliyet
  }
}

# --- CloudWatch log group (tum container'lar tek grupta, stream prefix ayirir) ---
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7 # maliyet
}

locals {
  log_config = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.this.name
      "awslogs-region"        = var.region
      "awslogs-stream-prefix" = "ecs"
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.project
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64" # imajlar linux/amd64 build edilir
  }

  container_definitions = jsonencode([
    # ---------------- redis (cache, ephemeral) ----------------
    {
      name             = "redis"
      image            = "redis:7-alpine"
      essential        = true
      logConfiguration = local.log_config
      healthCheck = {
        command     = ["CMD", "redis-cli", "ping"]
        interval    = 10
        timeout     = 5
        retries     = 5
        startPeriod = 10
      }
    },
    # ---------------- mongo (task verisi, ephemeral!) ----------------
    {
      name             = "mongo"
      image            = "mongo:7"
      essential        = true
      logConfiguration = local.log_config
      healthCheck = {
        command     = ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
        interval    = 10
        timeout     = 5
        retries     = 5
        startPeriod = 20
      }
    },
    # ---------------- backend (FastAPI + socketio) ----------------
    {
      name             = "backend"
      image            = var.backend_image
      essential        = true
      logConfiguration = local.log_config
      environment = [
        { name = "POSTGRES_HOST", value = var.postgres_host },
        { name = "POSTGRES_PORT", value = tostring(var.postgres_port) },
        { name = "POSTGRES_DB", value = var.postgres_db },
        { name = "POSTGRES_USER", value = var.postgres_user },
        { name = "MONGODB_URI", value = "mongodb://127.0.0.1:27017/taskdb" },
        { name = "REDIS_HOST", value = "127.0.0.1" },
        { name = "REDIS_PORT", value = "6379" },
        { name = "JWT_EXPIRES_IN", value = "7d" },
      ]
      secrets = [
        { name = "POSTGRES_PASSWORD", valueFrom = var.db_password_secret_arn },
        { name = "JWT_SECRET", valueFrom = var.jwt_secret_arn },
      ]
      dependsOn = [
        { containerName = "mongo", condition = "HEALTHY" },
        { containerName = "redis", condition = "HEALTHY" },
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60 # create_all + baglantilar icin sure
      }
    },
    # ---------------- nginx (ALB target, SPA + reverse proxy) ----------------
    {
      name             = "nginx"
      image            = var.nginx_image
      essential        = true
      logConfiguration = local.log_config
      environment = [
        { name = "BACKEND_HOST", value = "127.0.0.1" }, # tek task loopback
      ]
      portMappings = [
        { containerPort = 80, protocol = "tcp" }
      ]
      dependsOn = [
        { containerName = "backend", condition = "HEALTHY" }
      ]
    },
  ])
}

resource "aws_ecs_service" "this" {
  name            = "${var.project}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Tek task + ephemeral sidecar: yeni task eskisini degistirmeden once
  # eskiyi durdur (ayni anda 2 task olmasin). Kisa kesinti kabul.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = true # NAT yok -> ECR/Secrets/Logs public IP ile
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "nginx"
    container_port   = 80
  }

  # CI/CD task def revizyonlarini yonetir; TF ilk revizyonu kurar sonra karismaz
  lifecycle {
    ignore_changes = [task_definition]
  }
  # Not: ALB listener bagimliligi kok modulde depends_on = [module.alb] ile kurulur
  # ("target group not associated with load balancer" hatasini onlemek icin).
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_family" {
  value = aws_ecs_task_definition.this.family
}
