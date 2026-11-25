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

  # feast/ 경로(Feast registry)에서 덮어써서 밀려난 옛 버전만 30일 뒤 지운다(이슈 #57).
  # versioning은 버킷 단위지만 수명 규칙은 경로로 제한할 수 있다. MLflow 모델 파일(mlflow/)의 옛 버전은 지우지 않는다(PR #64 리뷰).
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
      matches_prefix             = ["feast/"]
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(local.labels, { purpose = "model-artifacts" })

  lifecycle {
    prevent_destroy = true
  }
}
