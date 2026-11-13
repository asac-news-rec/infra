# data-ml 파이프라인(윤모 님)이 쓰는 BigQuery 데이터셋과 권한 (이슈 #29).
# 데이터셋 위치는 만든 뒤 바꿀 수 없어서 raw-logs 버킷과 같은 서울로 둔다.

variable "data_ml_users" {
  description = "data-ml 개발자의 구글 계정 목록. 코드에 적지 않고 로컬 terraform.tfvars로 받는다."
  type        = list(string)
  default     = []
}

locals {
  # raw(원본 적재) -> clean(정제) -> agg(집계) -> feat(피처) -> train(학습 데이터). dev_yoonmo는 개인 시험용.
  bq_datasets = toset(["raw", "clean", "agg", "feat", "train", "dev_yoonmo"])

  # 데이터셋 x 계정 조합마다 권한 한 줄.
  bq_dataset_editors = {
    for pair in setproduct(local.bq_datasets, var.data_ml_users) :
    "${pair[0]}/${pair[1]}" => { dataset_id = pair[0], user = pair[1] }
  }
}

resource "google_bigquery_dataset" "data_ml" {
  for_each   = local.bq_datasets
  project    = var.project_id
  dataset_id = each.value
  location   = var.region

  labels = merge(local.labels, { purpose = "data-ml" })

  # 테이블이 들어 있으면 destroy가 막히도록 둔다(실수로 데이터를 지우지 않게).
  delete_contents_on_destroy = false
}

# 쿼리를 실행할 수 있는 권한(프로젝트 수준). 데이터는 아래 데이터셋 권한으로만 읽고 쓴다.
resource "google_project_iam_member" "data_ml_bigquery_job_user" {
  for_each = toset(var.data_ml_users)
  project  = var.project_id
  role     = "roles/bigquery.jobUser"
  member   = "user:${each.value}"
}

# 위 6개 데이터셋에서만 테이블을 만들고 읽고 쓴다.
resource "google_bigquery_dataset_iam_member" "data_ml_editor" {
  for_each   = local.bq_dataset_editors
  project    = var.project_id
  dataset_id = google_bigquery_dataset.data_ml[each.value.dataset_id].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "user:${each.value.user}"
}

# raw-logs 버킷 전체 읽기(DAG가 served/, actions/, simulator/를 읽는다).
resource "google_storage_bucket_iam_member" "data_ml_raw_logs_viewer" {
  for_each = toset(var.data_ml_users)
  bucket   = google_storage_bucket.raw_logs.name
  role     = "roles/storage.objectViewer"
  member   = "user:${each.value}"
}

# simulator/ 경로에서만 파일을 만들고 덮어쓰고 지울 수 있다(가짜 로그를 다시 만들 때 필요).
resource "google_storage_bucket_iam_member" "data_ml_raw_logs_simulator_writer" {
  for_each = toset(var.data_ml_users)
  bucket   = google_storage_bucket.raw_logs.name
  role     = "roles/storage.objectUser"
  member   = "user:${each.value}"

  condition {
    title       = "simulator-prefix-only"
    description = "simulator/ 경로의 객체만 생성·삭제"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.raw_logs.name}/objects/simulator/\")"
  }
}
