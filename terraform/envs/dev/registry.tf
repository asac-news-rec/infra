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

# Docker Hub 이미지 복사본(미러). 비공개 GKE 노드는 인터넷에 직접 나가지 못해 Docker Hub에서 이미지를 받을 수 없다.
# 대신 이 저장소에서 받으면, 처음 요청할 때 Artifact Registry가 Docker Hub에서 가져와 보관한다.
# 사용 예: apache/airflow:2.x 는 <리전>-docker.pkg.dev/<프로젝트>/dockerhub-mirror/apache/airflow:2.x
#          공식 이미지(nginx 등)는 앞에 library/ 가 붙는다: .../dockerhub-mirror/library/nginx
# Docker Hub가 아닌 곳(registry.k8s.io, quay.io 등)의 이미지는 이 저장소로 받을 수 없다([확인 필요]).
resource "google_artifact_registry_repository" "dockerhub_mirror" {
  project       = var.project_id
  location      = var.region
  repository_id = "dockerhub-mirror"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  description   = "Docker Hub 이미지 복사본(비공개 GKE 노드용)"

  remote_repository_config {
    description = "Docker Hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  labels = local.labels

  depends_on = [google_project_service.apis]
}
