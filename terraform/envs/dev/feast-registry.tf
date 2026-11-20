# Feast registry(GCS)와 Airflow BigQuery 권한 (이슈 #57).
# registry는 model-artifacts 버킷의 feast/registry.pb 파일이다.
#   - 로컬에서 `feast apply`를 실행하는 사람: feast/ 읽기·쓰기
#   - Airflow materialize 작업(서비스 계정 airflow): feast/ 읽기·쓰기
#   - 추론 서버(서비스 계정 inference-server): feast/ 읽기
# 서비스 계정 airflow는 이슈 #37(PR #45)이 만든다. #59와 같이 이름으로 참조하므로 #45가 머지되기 전에도 plan이 가능하다(계정은 이미 존재).

variable "feast_registry_users" {
  description = "로컬에서 feast apply를 실행하는 사람의 구글 계정 목록. 코드에 적지 않고 로컬 terraform.tfvars로 받는다."
  type        = list(string)
  default     = []

  # 값을 넣지 않고 apply하면 이미 적용된 권한이 조용히 삭제된다. 빈 목록을 막는다.
  validation {
    condition     = length(var.feast_registry_users) > 0
    error_message = "feast_registry_users가 비어 있습니다. terraform.tfvars에 feast apply를 실행하는 구글 계정을 넣어 주세요(terraform.tfvars.example 참고)."
  }
}

locals {
  feast_registry_prefix = "feast/"
  feast_airflow_member  = "serviceAccount:airflow@${var.project_id}.iam.gserviceaccount.com"

  # feast/ 경로의 객체만 대상으로 하는 조건.
  feast_registry_condition = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.model_artifacts.name}/objects/${local.feast_registry_prefix}\")"
}

# 추론 서버(GKE 파드)가 GCP 자원을 읽을 때 쓰는 신분. 키 파일은 만들지 않는다.
# 쿠버네티스 서비스 계정과의 Workload Identity 연결은 추론 서버를 올릴 때 추가한다.
resource "google_service_account" "inference_server" {
  project      = var.project_id
  account_id   = "inference-server"
  display_name = "Inference server (GKE)"
}

# 로컬 feast apply: feast/ 경로의 객체를 읽고 쓴다(덮어쓰기에 필요한 삭제 권한이 objectUser에 들어 있다).
resource "google_storage_bucket_iam_member" "feast_registry_users" {
  for_each = toset(var.feast_registry_users)
  bucket   = google_storage_bucket.model_artifacts.name
  role     = "roles/storage.objectUser"
  member   = "user:${each.value}"

  condition {
    title       = "feast-prefix-only"
    description = "feast/ 경로의 객체만"
    expression  = local.feast_registry_condition
  }
}

# Airflow materialize 작업은 registry를 읽고 쓴다.
resource "google_storage_bucket_iam_member" "feast_registry_airflow" {
  bucket = google_storage_bucket.model_artifacts.name
  role   = "roles/storage.objectUser"
  member = local.feast_airflow_member

  condition {
    title       = "feast-prefix-only"
    description = "feast/ 경로의 객체만"
    expression  = local.feast_registry_condition
  }
}

# 추론 서버는 registry를 읽기만 한다.
resource "google_storage_bucket_iam_member" "feast_registry_inference" {
  bucket = google_storage_bucket.model_artifacts.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.inference_server.email}"

  condition {
    title       = "feast-prefix-only"
    description = "feast/ 경로의 객체만"
    expression  = local.feast_registry_condition
  }
}

# materialize가 쓰는 BigQuery 권한. 임시 표를 만들고 읽는 데이터셋은 dev_yoonmo 하나다.
# 데이터셋은 이슈 #29가 만들었고, 여기서는 이름으로 참조한다.
resource "google_bigquery_dataset_iam_member" "airflow_dev_yoonmo_editor" {
  project    = var.project_id
  dataset_id = "dev_yoonmo"
  role       = "roles/bigquery.dataEditor"
  member     = local.feast_airflow_member
}

# 쿼리를 실행할 수 있는 권한(프로젝트 수준). 데이터는 위 데이터셋 권한으로만 읽고 쓴다.
resource "google_project_iam_member" "airflow_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = local.feast_airflow_member
}

output "inference_server_service_account" {
  description = "추론 서버 서비스 계정 이메일."
  value       = google_service_account.inference_server.email
}
