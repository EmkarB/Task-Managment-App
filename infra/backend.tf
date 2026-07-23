# Remote state - S3 + DynamoDB lock.
# Bu degerler bootstrap ciktilariyla doldurulur. Bucket/tablo ONCE olusmali.
#
# `terraform init` sirasinda -backend-config ile de gecebilirsiniz:
#   terraform init \
#     -backend-config="bucket=taskapp-tfstate-XXXX-eucentral1" \
#     -backend-config="dynamodb_table=taskapp-tf-lock" \
#     -backend-config="region=eu-south-2"
terraform {
  backend "s3" {
    key     = "taskapp/terraform.tfstate"
    encrypt = true
    # bucket, dynamodb_table, region -> init -backend-config ile verilir
    # eu-south-2 opt-in region; eski backend region listesinde yok -> dogrulamayi atla
    skip_region_validation = true
  }
}
