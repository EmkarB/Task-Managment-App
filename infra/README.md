# Task-Managment-App — AWS Deploy (ECS Fargate + ALB + RDS)

Bu klasör, uygulamayı AWS'e taşıyan Terraform altyapısını içerir.
Hedef: **öğrenme + minimum maliyet**.

## Mimari

```
Internet → ALB(:80) → Fargate task (public subnet, public IP)
                        ├─ nginx   :80   (ALB hedefi, SPA + /api & /socket.io reverse proxy)
                        ├─ backend :8000 (FastAPI + socket.io, loopback)
                        ├─ mongo   :27017 (sidecar, EPHEMERAL)
                        └─ redis   :6379  (sidecar, EPHEMERAL, cache)
                        backend → RDS PostgreSQL (private subnet :5432)
```

- **Tek task, `desired_count=1`** — backend websocket state'i bellek-içi (Redis adapter yok)
  ve `create_all` her açılışta çalışır; birden fazla task bunu bozar.
- **NAT Gateway yok** — task public subnet'te public IP ile ECR/Secrets/Logs'a erişir (~$32/ay tasarruf).
- **EFS yok** — mongo/redis ephemeral. ⚠️ **Her deploy/restart'ta tüm task ve kullanıcı-dışı veri sıfırlanır.**
  (Postgres/RDS kalıcıdır; kullanıcı hesapları orada. Task'lar Mongo'da olduğu için task'lar silinir.)
- **Sadece HTTP :80** — TLS/domain sonraki faz.

> **Region: `eu-south-2` (İspanya / Zaragoza)** — opt-in region, hesapta etkin olmalı.
> VPC CIDR `10.42.0.0/16` seçildi; region'daki mevcut `172.31.0.0/16` (default) ve
> `10.3.0.0/16` (viewcraft) VPC'leriyle çakışmaz.

## Yaklaşık aylık maliyet (eu-south-2, kabaca)

| Kaynak | Tahmini |
|---|---|
| ALB | ~$16 + trafik |
| Fargate 0.5 vCPU / 1GB (1 task, 7/24) | ~$18 |
| RDS db.t3.micro single-AZ + 20GB | ~$15 (free-tier'da ilk yıl ~$0) |
| ECR/Logs/Secrets | birkaç $ |

> NAT ve EFS bilinçli olarak **yok** — en pahalı sabit kalemler elendi.

## Kurulum sırası

### 0) Gereksinimler
- Terraform >= 1.5, AWS CLI, geçerli AWS kimlik bilgileri (`aws sts get-caller-identity`).

### 1) Remote state (bir kez)
```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars   # state_bucket_name'i BENZERSIZ yapın
terraform init && terraform apply
# çıktı: state_bucket, lock_table
```

### 2) Ana altyapı
```bash
cd ../
terraform init \
  -backend-config="bucket=<bootstrap state_bucket>" \
  -backend-config="dynamodb_table=<bootstrap lock_table>" \
  -backend-config="region=eu-south-2"

terraform apply
# çıktılar: alb_url, ecr_*_repo_url, ecs_*, github_deploy_role_arn, github_actions_variables
```

İlk apply, container imajları için **placeholder** (public busybox/nginx) kullanır — task ayağa
kalkar ama gerçek uygulama CI ilk imajları push edene kadar çalışmaz. Bu normaldir.

### 3) GitHub Actions değişkenleri
`terraform output github_actions_variables` çıktısındaki değerleri
**GitHub repo → Settings → Secrets and variables → Actions → Variables** altına ekleyin:

- `AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `ECR_BACKEND_REPO`, `ECR_NGINX_REPO`,
  `ECS_CLUSTER`, `ECS_SERVICE`, `ECS_TASK_FAMILY`

> **Secret gerekmez** — OIDC ile kimlik doğrulanır, uygulama secret'ları AWS Secrets Manager'da.

### 4) İlk deploy
`main` branch'ine push edin → `.github/workflows/deploy.yml` imajları build/push eder
(`linux/amd64`) ve yeni ECS task revizyonunu deploy eder.

## Doğrulama

```bash
ALB=$(terraform output -raw alb_url)
curl -i $ALB/healthz          # 200 ok  (nginx canlı)
curl -s $ALB/api/health       # {"status":"healthy","postgres":"connected",...}
```
Tarayıcıda `$ALB`: kayıt/giriş (RDS), task ekleme (Mongo), ikinci sekmede canlı güncelleme (websocket).

## Temizlik (maliyet durdurma)
```bash
cd infra && terraform destroy
cd bootstrap && terraform destroy   # state bucket/lock (en son)
```

## Sonraki faz (production'a doğru)
- Mongo → DocumentDB / Atlas, Redis → ElastiCache (kalıcılık + backend'i stateless yapar)
- backend socket.io `AsyncRedisManager` + ALB target group stickiness → çok task / autoscaling
- HTTPS: ACM sertifikası + Route53 domain + :443 listener
- `create_all` yerine Alembic migration (init container)
