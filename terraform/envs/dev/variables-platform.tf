variable "bastion_users" {
  description = "배스천에 접속할 사람. 예: [\"user:name@gmail.com\"]. 이메일이 들어가므로 terraform.tfvars에만 적고 커밋하지 않는다."
  type        = list(string)
  default     = []
}

variable "extra_authorized_cidrs" {
  description = "GKE 제어면에 접근할 수 있게 추가로 허용할 IP 대역. 예: 내 공인 IP [\"1.2.3.4/32\"]. 배스천은 자동 허용된다."
  type        = list(string)
  default     = []
}

variable "gke_deletion_protection" {
  description = "true면 terraform destroy로 클러스터를 지울 수 없다. 개발 중에는 비용 절약을 위해 지울 수 있게 false."
  type        = bool
  default     = false
}

variable "db_version" {
  description = "Cloud SQL PostgreSQL 버전."
  type        = string
  default     = "POSTGRES_16"
}

variable "db_tier" {
  description = "Cloud SQL 사양. 가장 작은 공유 코어."
  type        = string
  default     = "db-f1-micro"
}
