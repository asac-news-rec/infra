# Airflow 작업이 GCP(GCS)에 접근하는 신분 (이슈 #37).
# 키 파일 없이 Workload Identity로 쿠버네티스 서비스 계정과 연결한다(MLflow와 같은 방식).
# 권한은 행동 로그 내보내기 DAG가 쓰는 것만 준다: 객체 생성, 조회(재시도 시 검증), 삭제(철회된 사용자 정리).
resource "google_service_account" "airflow" {
  project      = var.project_id
  account_id   = "airflow"
  display_name = "Airflow task runner"
}

locals {
  # Airflow 네임스페이스의 쿠버네티스 서비스 계정: 스케줄러(LocalExecutor 작업), 트리거러, KubernetesPodOperator 작업 파드 전용 계정(airflow-task).
  # airflow-task는 차트가 만들지 않으므로 kubectl로 따로 만든다. LocalExecutor에서는 차트가 airflow-worker 계정을 만들지 않는다(11/17 확인).
  airflow_ksas = ["airflow-scheduler", "airflow-triggerer", "airflow-task"]
  # 행동 로그 내보내기 DAG가 쓰는 raw-logs 경로
  airflow_export_dirs = ["served", "actions", "manifests"]
}

resource "google_service_account_iam_member" "airflow_workload_identity" {
  for_each = toset(local.airflow_ksas)

  service_account_id = google_service_account.airflow.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[airflow/${each.value}]"
}

# 목록 조회와 덮어쓰기(update) 권한은 주지 않는다.
resource "google_project_iam_custom_role" "airflow_raw_logs" {
  project     = var.project_id
  role_id     = "${replace(var.name_prefix, "-", "_")}_airflow_raw_logs"
  title       = "Airflow raw logs exporter"
  description = "raw-logs 버킷의 객체를 만들고, 조회하고, 지울 수 있다. 행동 로그 내보내기 DAG용."

  permissions = [
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.delete",
  ]
}

resource "google_storage_bucket_iam_member" "airflow_raw_logs" {
  bucket = google_storage_bucket.raw_logs.name
  role   = google_project_iam_custom_role.airflow_raw_logs.id
  member = "serviceAccount:${google_service_account.airflow.email}"

  condition {
    title       = "export-paths-only"
    description = "served/, actions/, manifests/ 경로의 객체만"
    expression  = join(" || ", [for d in local.airflow_export_dirs : "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.raw_logs.name}/objects/${d}/\")"])
  }
}

output "airflow_service_account" {
  value = google_service_account.airflow.email
}
