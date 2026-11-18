# 로깅 서버(Cloud Run)가 Cloud SQL의 behavior_logs DB에 접속하기 위한 권한(이슈 #52).
# Cloud Run은 내장 Auth Proxy(Unix 소켓)로 접속하므로 서비스 계정에 Cloud SQL Client 역할이 필요하다.
# DB 접속 문자열(비밀번호 포함)은 Secret Manager의 logging-api-database-url에 있고, 값은 Terraform으로 만들지 않는다.

resource "google_project_iam_member" "logging_server_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.logging_server.email}"
}

# 접속 문자열 Secret 하나만 읽을 수 있다(그 Secret에만).
resource "google_secret_manager_secret_iam_member" "logging_server_database_url" {
  project   = var.project_id
  secret_id = "logging-api-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.logging_server.email}"
}
