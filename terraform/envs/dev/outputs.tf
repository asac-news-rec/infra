output "raw_logs_bucket" {
  description = "원본 로그 버킷 이름."
  value       = google_storage_bucket.raw_logs.name
}

output "model_artifacts_bucket" {
  description = "모델 파일 버킷 이름."
  value       = google_storage_bucket.model_artifacts.name
}

output "image_registry" {
  description = "도커 이미지 주소의 앞부분. 이미지 이름과 태그를 뒤에 붙여 쓴다."
  value       = "${google_artifact_registry_repository.images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "logging_server_service_account" {
  description = "로깅 서버 서비스 계정 이메일."
  value       = google_service_account.logging_server.email
}

output "github_actions_service_account" {
  description = "GitHub Actions 서비스 계정 이메일."
  value       = google_service_account.github_actions.email
}
