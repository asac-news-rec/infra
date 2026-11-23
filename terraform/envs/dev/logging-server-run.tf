# 로깅 서버(FastAPI)를 Cloud Run에 처음 만들고, frontend 저장소의 GitHub Actions가 이후 이미지를 갱신할 수 있게 한다(이슈 #58).
#
# 적용 순서(두 번에 나눔): Cloud Run 리비전은 Secret 값과 이미지가 있어야 뜬다.
#   1) Secret 껍데기·읽기 권한, 배포 계정·권한 → 2) 사람이 Secret 값 생성·최초 이미지 push(Terraform 밖)
#   → 3) Cloud Run 서비스와 호출 권한. 자세한 명령은 README-platform.md 「로깅 서버 Cloud Run」.
#
# 앞선 PR과 이름이 겹치지 않도록 PR #48(WIF pool)과 PR #53(Cloud SQL 권한)의 리소스는 이름 문자열로 참조한다.
# 두 PR은 이미 적용되어 있다(WIF provider는 11/23 gcloud로, logging-server의 cloudsql.client는 같은 날 확인).

data "google_project" "logging_deploy" {
  project_id = var.project_id
}

locals {
  logging_server_name   = "logging-server"
  logging_server_image  = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/logging-server"
  logging_initial_tag   = "8bacd79" # frontend 커밋 8bacd79(Airflow 이미지 3.2.2-logging-8bacd79와 같은 코드 기준)
  logging_caller_member = "serviceAccount:news-feed-run@${var.project_id}.iam.gserviceaccount.com"

  # frontend 저장소 logging-production 환경 실행만. subject는 저장소 이름이 아니라 불변 ID 형식(#40에서 확인).
  logging_deploy_wif_member = "principal://iam.googleapis.com/projects/${data.google_project.logging_deploy.number}/locations/global/workloadIdentityPools/github/subject/repo:asac-news-rec@349611381/frontend@1437850587:environment:logging-production"
}

# --- 1) 공유 토큰 Secret -------------------------------------------------------
# 앱은 LOGGING_TOKEN이 24자 이상이어야 기동한다. 값은 코드·state에 넣지 않고 사람이 무작위로 만들어 넣는다(README).
resource "google_secret_manager_secret" "logging_api_token" {
  project   = var.project_id
  secret_id = "logging-api-token"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = merge(local.labels, { purpose = "logging-server" })
}

# 받는 쪽(logging-server)과 보내는 쪽(news-feed의 런타임 계정)이 같은 Secret을 읽는다. 값을 복사해 전달하지 않는다.
resource "google_secret_manager_secret_iam_member" "logging_token_server" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.logging_api_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.logging_server.email}"
}

resource "google_secret_manager_secret_iam_member" "logging_token_caller" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.logging_api_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.logging_caller_member
}

# --- 1) 배포 계정 -------------------------------------------------------------
# frontend-deploy를 넓히지 않고 로깅 전용 계정을 둔다. 한쪽 workflow 문제가 다른 서비스로 번지지 않게 한다.
resource "google_service_account" "logging_deploy" {
  project      = var.project_id
  account_id   = "logging-deploy"
  display_name = "Logging server CI/CD deploy (GitHub Actions)"
}

resource "google_service_account_iam_member" "logging_deploy_wif" {
  service_account_id = google_service_account.logging_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.logging_deploy_wif_member
}

# 이미지 창고(news-rec)에 이미지를 올릴 수 있다.
resource "google_artifact_registry_repository_iam_member" "logging_deploy_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.logging_deploy.email}"
}

# 서비스를 갱신하려면 그 서비스의 런타임 계정(logging-server)을 "사용"할 권한이 필요하다(그 계정에만).
resource "google_service_account_iam_member" "logging_deploy_act_as" {
  service_account_id = google_service_account.logging_server.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.logging_deploy.email}"
}

# --- 3) Cloud Run 서비스 ------------------------------------------------------
resource "google_cloud_run_v2_service" "logging_server" {
  project  = var.project_id
  name     = local.logging_server_name
  location = var.region

  # 인그레스는 모든 경로 허용, 대신 IAM 인증을 요구한다(allUsers invoker 없음).
  # Cloud Run(news-feed)에서 호출할 때 ID 토큰이 없으면 403. 내부 전용(internal)은 news-feed의 VPC 연결이 필요해 이번 범위 밖.
  ingress = "INGRESS_TRAFFIC_ALL"

  # dev 환경이라 롤백(destroy)이 가능하도록 끈다. 데이터는 Cloud SQL에 있어 서비스를 지워도 남는다.
  deletion_protection = false

  labels = local.labels

  template {
    service_account = google_service_account.logging_server.email

    # 최소 0(요청 없으면 과금 없음), 최대 1(Cloud SQL max_connections 50 안에서 연결 수를 예측 가능하게).
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${var.project_id}:${var.region}:${var.name_prefix}-pg"] # 문자열 참조: 인스턴스 사양은 PR #53이 바꿔 둔 상태라 이 PR의 -target에 끌려오지 않게 한다
      }
    }

    containers {
      image = "${local.logging_server_image}:${local.logging_initial_tag}"

      ports {
        container_port = 4195
      }

      env {
        name  = "LOGGING_HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "LOGGING_PORT"
        value = "4195"
      }
      env {
        name  = "LOGGING_STORE"
        value = "postgres"
      }
      # Unix 소켓(/cloudsql/...) 접속 문자열. Secret과 읽기 권한은 PR #53(#52)에서 만들었다.
      env {
        name = "LOGGING_DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = "logging-api-database-url"
            version = "latest"
          }
        }
      }
      env {
        name = "LOGGING_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.logging_api_token.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
  }

  # 이미지는 frontend workflow가 커밋 SHA 태그로 바꾼다. Terraform이 이를 최초 태그로 되돌리지 않게 무시한다.
  # client·client_version은 gcloud로 갱신할 때 바뀌는 표시용 값이라 함께 무시한다.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_secret_manager_secret_iam_member.logging_token_server,
  ]
}

# workflow가 이 서비스만 조회·갱신할 수 있다.
resource "google_cloud_run_v2_service_iam_member" "logging_deploy_run" {
  project  = var.project_id
  location = google_cloud_run_v2_service.logging_server.location
  name     = google_cloud_run_v2_service.logging_server.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.logging_deploy.email}"
}

# 호출은 news-feed의 런타임 계정만(세호 님 선택 A: 서버에서 호출 + Cloud Run IAM 인증).
resource "google_cloud_run_v2_service_iam_member" "logging_invoker_news_feed" {
  project  = var.project_id
  location = google_cloud_run_v2_service.logging_server.location
  name     = google_cloud_run_v2_service.logging_server.name
  role     = "roles/run.invoker"
  member   = local.logging_caller_member
}
