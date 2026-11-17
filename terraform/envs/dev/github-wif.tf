# GitHub Actions가 키 파일 없이 GCP에 인증하는 설정(Workload Identity Federation, 이슈 #40).
# GitHub가 실행마다 주는 증명서(OIDC)를 구글이 확인하고, 조건에 맞는 실행만 배포 서비스 계정을 대신 쓰게 한다.
data "google_project" "current" {
  project_id = var.project_id
}

resource "google_project_service" "wif_apis" {
  for_each = toset([
    "sts.googleapis.com",            # 외부(GitHub) 증명서를 구글 토큰으로 바꿈
    "iamcredentials.googleapis.com", # 서비스 계정을 대신 사용(토큰 발급)
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.wif_apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  # 조직 asac-news-rec의 실행만 받는다(다른 조직·개인 저장소는 이 공급자를 쓸 수 없다).
  attribute_condition = "assertion.repository_owner == 'asac-news-rec'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

locals {
  github_subject_prefix = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/subject"
}

# 프런트 CI/CD가 이미지를 올리고 Cloud Run을 갱신할 때 쓰는 계정.
resource "google_service_account" "frontend_deploy" {
  project      = var.project_id
  account_id   = "frontend-deploy"
  display_name = "Frontend CI/CD deploy (GitHub Actions)"
}

# asac-news-rec/frontend 의 frontend-production 환경 실행만 이 계정을 대신 쓸 수 있다.
resource "google_service_account_iam_member" "frontend_deploy_wif" {
  service_account_id = google_service_account.frontend_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.github_subject_prefix}/repo:asac-news-rec/frontend:environment:frontend-production"
}

# 이미지 창고(news-rec)에 이미지를 올릴 수 있다.
resource "google_artifact_registry_repository_iam_member" "frontend_deploy_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.frontend_deploy.email}"
}

# Cloud Run news-feed 서비스만 갱신할 수 있다(새 버전 배포).
resource "google_cloud_run_v2_service_iam_member" "frontend_deploy_run" {
  project  = var.project_id
  location = var.region
  name     = "news-feed"
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.frontend_deploy.email}"
}

# 서비스를 갱신하려면 서비스가 쓰는 런타임 계정을 "사용"할 권한이 필요하다(그 계정에만).
data "google_service_account" "news_feed_run" {
  project    = var.project_id
  account_id = "news-feed-run"
}

resource "google_service_account_iam_member" "frontend_deploy_act_as" {
  service_account_id = data.google_service_account.news_feed_run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.frontend_deploy.email}"
}

output "github_wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "frontend_deploy_service_account" {
  value = google_service_account.frontend_deploy.email
}
