# 로깅 서버가 JSONL.gz 원본을 저장하고, Airflow가 읽는 버킷 (5분 파티션: served/, actions/).
resource "google_storage_bucket" "raw_logs" {
  name     = "${var.project_id}-raw-logs"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  labels = merge(local.labels, { purpose = "raw-logs" })

  lifecycle {
    prevent_destroy = true
  }
}

# 학습한 모델 파일 보관. MLflow가 위치를 참조하고 추론 서버가 읽는다.
resource "google_storage_bucket" "model_artifacts" {
  name     = "${var.project_id}-model-artifacts"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  # 모델 파일을 실수로 덮어써도 되돌릴 수 있게 한다.
  versioning {
    enabled = true
  }

  labels = merge(local.labels, { purpose = "model-artifacts" })

  lifecycle {
    prevent_destroy = true
  }
}
