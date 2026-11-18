# MLflow 서버(GKE)가 쓰는 구글 서비스 계정과 권한.
# 서버는 모델 파일을 model-artifacts 버킷(mlflow/ 경로)에 읽고 쓴다.
# 키 파일은 만들지 않고, 파드가 Workload Identity로 이 계정의 신분을 빌려 쓴다.
resource "google_service_account" "mlflow_server" {
  project      = var.project_id
  account_id   = "mlflow-server"
  display_name = "MLflow server (GKE)"
}

# 이 버킷에서만 파일을 읽고 쓰고 지울 수 있다(다른 버킷은 불가). 범위는 버킷 전체이고 mlflow/ 경로로 좁히지는 않았다.
# objectAdmin은 객체의 IAM 정책까지 바꿀 수 있어서, 읽기·쓰기·삭제만 가진 objectUser로 줄였다(PR #34 리뷰).
# mlflow/ 경로로 더 좁히는 것은 목록 조회와 조건부 권한의 제약을 확인한 뒤 후속으로 한다.
resource "google_storage_bucket_iam_member" "mlflow_server_model_artifacts" {
  bucket = google_storage_bucket.model_artifacts.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.mlflow_server.email}"
}

# 쿠버네티스의 mlflow 네임스페이스에 있는 mlflow 서비스 계정만 위 구글 계정의 신분을 빌릴 수 있다.
resource "google_service_account_iam_member" "mlflow_server_workload_identity" {
  service_account_id = google_service_account.mlflow_server.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[mlflow/mlflow]"
}
