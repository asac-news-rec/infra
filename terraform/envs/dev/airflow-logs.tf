# Airflow 로그를 디스크 대신 GCS에 저장한다(이슈 #50, 멘토 11/16).
# 디스크가 가득 차 서버가 멈추는 것을 막고, 수명주기 규칙으로 60일이 지난 로그를 자동 삭제한다.
# 주의: GCS의 "보존 정책(retention policy)"은 삭제를 막는 기능이라 여기서 쓰지 않는다.
resource "google_storage_bucket" "airflow_logs" {
  project  = var.project_id
  name     = "${var.project_id}-airflow-logs"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = local.labels

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 60
    }
  }
}

# Airflow 서비스 계정(이슈 #37, PR #45)에 이 버킷의 객체 읽기·쓰기 권한만 준다.
# 서비스 계정은 #45가 만든 것을 이름으로 참조한다(#45 머지 전에도 이미 만들어져 있음).
resource "google_storage_bucket_iam_member" "airflow_logs_objects" {
  bucket = google_storage_bucket.airflow_logs.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:airflow@${var.project_id}.iam.gserviceaccount.com"
}

# Airflow 화면(API 서버)이 GCS의 로그를 읽어 보여 주려면, API 서버의 쿠버네티스 서비스 계정도
# GCP 서비스 계정 airflow를 쓸 수 있어야 한다(작업 로그는 스케줄러·트리거러가 올린다).
resource "google_service_account_iam_member" "airflow_api_server_wif" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/airflow@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[airflow/airflow-api-server]"
}
