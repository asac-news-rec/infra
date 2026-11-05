provider "google" {
  project = var.project_id
  region  = var.region

  # 내 구글 로그인(ADC)으로 실행할 때, API 사용량을 이 프로젝트에 청구하도록 지정한다.
  user_project_override = true
  billing_project       = var.project_id
}

locals {
  labels = {
    project = var.name_prefix
    env     = "dev"
  }
}
