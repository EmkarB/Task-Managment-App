output "alb_url" {
  description = "Uygulama adresi"
  value       = "http://${module.alb.dns_name}"
}

output "ecr_backend_repo_url" {
  value = module.ecr.backend_repo_url
}

output "ecr_nginx_repo_url" {
  value = module.ecr.nginx_repo_url
}

output "ecr_backend_repo_name" {
  value = module.ecr.backend_repo_name
}

output "ecr_nginx_repo_name" {
  value = module.ecr.nginx_repo_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "ecs_task_family" {
  value = module.ecs.task_family
}

output "rds_endpoint" {
  value = module.rds.address
}

output "github_deploy_role_arn" {
  description = "GitHub Actions AWS_DEPLOY_ROLE_ARN degiskenine yazin"
  value       = module.iam.github_deploy_role_arn
}

# CI/CD icin GitHub Variables ozeti
output "github_actions_variables" {
  description = "GitHub repo Variables olarak girilecek degerler"
  value = {
    AWS_REGION          = var.region
    AWS_DEPLOY_ROLE_ARN = module.iam.github_deploy_role_arn
    ECR_BACKEND_REPO    = module.ecr.backend_repo_url
    ECR_NGINX_REPO      = module.ecr.nginx_repo_url
    ECS_CLUSTER         = module.ecs.cluster_name
    ECS_SERVICE         = module.ecs.service_name
    ECS_TASK_FAMILY     = module.ecs.task_family
  }
}
