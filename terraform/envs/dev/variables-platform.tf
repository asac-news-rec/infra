variable "bastion_users" {
  description = "배스천에 접속할 사람. 예: [\"user:name@gmail.com\"]. 이메일이 들어가므로 terraform.tfvars에만 적고 커밋하지 않는다."
  type        = list(string)
  default     = []
}

variable "gke_master_cidr" {
  description = "GKE 관리 주소(제어면)가 쓰는 내부 IP 대역(/28). 우리 VPC의 다른 대역과 겹치지 않아야 한다."
  type        = string
  default     = "172.16.0.0/28"
}

variable "gke_fixed_machine_type" {
  description = "고정 노드 풀의 VM 사양. e2-standard-2는 2 vCPU, 8GB."
  type        = string
  default     = "e2-standard-2"
}

variable "gke_fixed_node_count" {
  description = "고정 노드 풀을 만들 때의 노드 수. 0이면 노드 요금이 없다. 쓸 때는 gcloud로 늘린다(README-platform.md)."
  type        = number
  default     = 0
}

variable "gke_worker_machine_type" {
  description = "작업용(worker) 노드 풀의 VM 사양."
  type        = string
  default     = "e2-standard-2"
}

variable "gke_worker_max_nodes" {
  description = "작업용 노드 풀이 자동으로 늘어나는 최대 개수(비용 상한)."
  type        = number
  default     = 2
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
  description = "Cloud SQL 사양. 서비스 DB, 로깅, Airflow, MLflow가 함께 쓰는 공유 코어."
  type        = string
  default     = "db-g1-small"
}
