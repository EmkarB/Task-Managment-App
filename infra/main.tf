# ---------------------------------------------------------------------------
# Kok kompozisyon - modulleri baglar.
# Bagimlilik: network -> securitygroups -> (ecr, iam, secrets) -> rds -> alb -> ecs
# ---------------------------------------------------------------------------

module "network" {
  source  = "./modules/network"
  project = var.project
  azs     = var.azs
}

module "securitygroups" {
  source  = "./modules/securitygroups"
  project = var.project
  vpc_id  = module.network.vpc_id
}

module "ecr" {
  source  = "./modules/ecr"
  project = var.project
}

module "secrets" {
  source  = "./modules/secrets"
  project = var.project
}

module "iam" {
  source        = "./modules/iam"
  project       = var.project
  github_repo   = var.github_repo
  github_branch = var.github_branch
  secret_arns = [
    module.secrets.db_password_secret_arn,
    module.secrets.jwt_secret_arn,
  ]
}

module "rds" {
  source                 = "./modules/rds"
  project                = var.project
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  task_security_group_id = module.securitygroups.task_sg_id
  db_password            = module.secrets.db_password_value
  instance_class         = var.db_instance_class
}

module "alb" {
  source                = "./modules/alb"
  project               = var.project
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.securitygroups.alb_sg_id
}

module "ecs" {
  source                 = "./modules/ecs"
  project                = var.project
  region                 = var.region
  public_subnet_ids      = module.network.public_subnet_ids
  task_security_group_id = module.securitygroups.task_sg_id
  target_group_arn       = module.alb.target_group_arn
  execution_role_arn     = module.iam.execution_role_arn
  task_role_arn          = module.iam.task_role_arn

  backend_image = var.backend_image
  nginx_image   = var.nginx_image

  postgres_host          = module.rds.address
  db_password_secret_arn = module.secrets.db_password_secret_arn
  jwt_secret_arn         = module.secrets.jwt_secret_arn

  # ALB listener olusmadan servis baslamasin (target group association hatasi)
  depends_on = [module.alb]
}
