variable "project" {
  description = "Proje adi (kaynak isimlendirme icin)"
  type        = string
}

# CIDR NOTU: eu-south-2'de mevcut VPC'ler var (default 172.31.0.0/16,
# viewcraft 10.3.0.0/16). Cakismayi onlemek icin 10.42.0.0/16 secildi.
variable "vpc_cidr" {
  description = "VPC CIDR blogu"
  type        = string
  default     = "10.42.0.0/16"
}

variable "azs" {
  description = "Kullanilacak availability zone'lar (2 tane)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR'lari (AZ sirasina gore)"
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR'lari (AZ sirasina gore)"
  type        = list(string)
  default     = ["10.42.10.0/24", "10.42.11.0/24"]
}
