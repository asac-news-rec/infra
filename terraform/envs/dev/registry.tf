# 도커 이미지 창고. GitHub Actions가 이미지를 올리고 Cloud Run·GKE가 가져간다.
resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = var.name_prefix
  format        = "DOCKER"
  description   = "뉴스 추천 서비스 도커 이미지"

  labels = local.labels

  # 태그 없는 이미지는 7일 뒤 자동 삭제해 저장 비용이 쌓이지 않게 한다.
  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"
    }
  }

  depends_on = [google_project_service.apis]
}
