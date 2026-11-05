# bootstrap: 처음 한 번만 실행한다.
# 하는 일: (1) Terraform 상태를 저장할 GCS 버킷을 만든다. (2) 그 버킷과 이후 작업에 필요한 기본 API를 켠다.
# 이 단계의 상태 파일은 로컬(terraform.tfstate)에 생기며 Git에는 올리지 않는다(.gitignore).

provider "google" {
  project = var.project_id
  region  = var.region

  # 내 구글 로그인(ADC)으로 실행할 때, API 사용량을 이 프로젝트에 청구하도록 지정한다.
  user_project_override = true
  billing_project       = var.project_id
}

# 기본 API 켜기. 이 API들이 꺼져 있으면 버킷 생성과 이후 작업이 실패한다.
locals {
  bootstrap_apis = [
    "serviceusage.googleapis.com",         # API를 켜고 끄는 API
    "cloudresourcemanager.googleapis.com", # 프로젝트 정보 조회
    "iam.googleapis.com",                  # 서비스 계정·권한
    "iamcredentials.googleapis.com",       # 서비스 계정 가장(impersonation)
    "storage.googleapis.com",              # Cloud Storage(버킷)
  ]
}

resource "google_project_service" "bootstrap" {
  for_each = toset(local.bootstrap_apis)

  project = var.project_id
  service = each.value

  # terraform destroy 때 API를 끄지 않는다(다른 리소스가 쓰고 있을 수 있음).
  disable_on_destroy = false
}

# Terraform 상태 파일을 저장할 버킷.
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # 상태 파일을 실수로 덮어써도 되돌릴 수 있게 버전 관리를 켠다.
  versioning {
    enabled = true
  }

  # 오래된 버전이 끝없이 쌓이지 않게 최근 10개만 남긴다.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # 비어 있지 않으면 삭제되지 않게 한다.
  force_destroy = false

  labels = {
    project = var.name_prefix
    purpose = "terraform-state"
  }

  # 실수로 지우는 것을 막는다.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.bootstrap]
}
