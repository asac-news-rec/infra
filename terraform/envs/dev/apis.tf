# 이후 단계에서 쓸 API를 미리 켠다. API를 켜는 것 자체는 비용이 들지 않는다.
# (GKE·Cloud SQL·Compute 관련 API는 해당 리소스를 만드는 PR에서 켠다.)
locals {
  apis = [
    "artifactregistry.googleapis.com", # 도커 이미지 창고
    "run.googleapis.com",              # Cloud Run
    "secretmanager.googleapis.com",    # 비밀값 보관
    "bigquery.googleapis.com",         # BigQuery
    "logging.googleapis.com",          # 로그
    "monitoring.googleapis.com",       # 모니터링
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project = var.project_id
  service = each.value

  # terraform destroy 때 API를 끄지 않는다(다른 리소스가 쓰고 있을 수 있음).
  disable_on_destroy = false
}
