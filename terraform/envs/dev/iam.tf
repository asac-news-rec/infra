# 서비스 계정: 사람이 아닌 프로그램 전용 계정. 키 파일은 만들지 않는다.
# 프로그램마다 필요한 권한만 부여한다(최소 권한).

# 로깅 서버(Cloud Run)가 사용하는 계정.
resource "google_service_account" "logging_server" {
  project      = var.project_id
  account_id   = "logging-server"
  display_name = "Logging server (Cloud Run)"
}

# 로깅 서버는 원본 로그 버킷에 파일을 "만들기"만 할 수 있다(읽기·삭제 불가).
resource "google_storage_bucket_iam_member" "logging_server_raw_logs" {
  bucket = google_storage_bucket.raw_logs.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.logging_server.email}"
}

# GitHub Actions가 이미지를 올릴 때 쓰는 계정.
# GitHub 인증(Workload Identity Federation)과 Cloud Run 배포 권한은 후속 PR에서 추가한다.
resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = "github-actions"
  display_name = "GitHub Actions (image push)"
}

# 이미지 창고에 이미지를 올릴 수 있다(그 창고에만).
resource "google_artifact_registry_repository_iam_member" "github_actions_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_actions.email}"
}
