# 플랫폼(네트워크, GKE, 배스천, Cloud SQL)에 필요한 API. 켜는 것 자체는 비용이 없다.
locals {
  platform_apis = [
    "compute.googleapis.com",   # 네트워크, VM
    "container.googleapis.com", # GKE
    "iap.googleapis.com",       # IAP(구글 인증 터널)로 배스천 접속
    "oslogin.googleapis.com",   # 구글 계정으로 VM 로그인
    "sqladmin.googleapis.com",  # Cloud SQL
  ]
}

resource "google_project_service" "platform_apis" {
  for_each = toset(local.platform_apis)

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
