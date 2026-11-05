variable "project_id" {
  description = "GCP 프로젝트 ID. 계정을 바꾸면 이 값만 바꾼다."
  type        = string
}

variable "region" {
  description = "리전 (서울)."
  type        = string
  default     = "asia-northeast3"
}

variable "name_prefix" {
  description = "리소스 이름 앞에 붙일 접두어."
  type        = string
  default     = "news-rec"
}
