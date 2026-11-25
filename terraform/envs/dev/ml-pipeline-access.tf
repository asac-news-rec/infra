# 윤모 님 데이터 파이프라인 DAG(load_raw, clean_events, embed_articles, build_feast_sources)가
# 클러스터에서 쓰는 권한과 비밀값 (이슈 #73).
# 작업 Pod는 KSA airflow/airflow-task → GCP 서비스 계정 airflow(이슈 #37, PR #45)로 실행된다.
# airflow 계정은 #45가 만들고, 여기서는 #63·#64처럼 이메일 문자열로 참조한다(#45 머지 전에도 plan 가능).
# 프로젝트 수준 roles/bigquery.jobUser(쿼리·적재 작업 실행)는 #64(feast-registry.tf)가 이미 준다.
locals {
  ml_pipeline_sa_member = "serviceAccount:airflow@${var.project_id}.iam.gserviceaccount.com"

  # 행동 로그 버킷. storage.tf의 리소스를 참조하지 않고 이름으로 둔다(-target이 버킷까지 끌고 오지 않게).
  ml_pipeline_raw_logs_bucket = "${var.project_id}-raw-logs"

  # BigQuery 데이터셋은 PR #33(bigquery.tf)이 만든다. 머지 전이라 이름으로 참조한다.
  # raw: GCS 로그 적재, clean: 정제 결과, feat: 임베딩·Feast 원천 표.
  ml_pipeline_bq_datasets = toset(["raw", "clean", "feat"])
}

# --- 행동 로그 버킷 읽기 ------------------------------------------------------
# load_raw가 GCS의 행동 로그 파일 목록을 보고(storage.objects.list) 내용을 읽는다(get).
# 읽기 전용이라 버킷 전체에 준다. 쓰기·삭제는 #45의 경로 조건부 권한(served/, actions/, manifests/)만 있다.
resource "google_storage_bucket_iam_member" "airflow_raw_logs_reader" {
  bucket = local.ml_pipeline_raw_logs_bucket
  role   = "roles/storage.objectViewer"
  member = local.ml_pipeline_sa_member
}

# --- BigQuery 데이터셋 편집 ---------------------------------------------------
# 표 생성·쓰기. 데이터셋 3개에만 주고 프로젝트 전체에는 주지 않는다.
resource "google_bigquery_dataset_iam_member" "airflow_ml_pipeline_editor" {
  for_each = local.ml_pipeline_bq_datasets

  project    = var.project_id
  dataset_id = each.value
  role       = "roles/bigquery.dataEditor"
  member     = local.ml_pipeline_sa_member
}

# --- 임베딩 작업의 DB 읽기 계정 비밀번호 --------------------------------------
# embed_articles가 newsdb의 기사를 읽을 때 쓰는 읽기 전용 DB 계정(news_ml_reader)의 비밀번호.
# 값은 코드와 state에 넣지 않는다. 껍데기만 만들고 값은 사람이 줄바꿈 없이 넣는다.
# DB 계정과 권한은 SQL로 만든다(sql/newsdb/V4__news_ml_reader.sql).
resource "google_secret_manager_secret" "news_db_ml_reader_password" {
  project   = var.project_id
  secret_id = "news-db-ml-reader-password"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = merge(local.labels, { purpose = "ml-pipeline" })
}

# 이 Secret을 읽을 수 있는 것은 airflow 계정뿐이다(이 Secret 하나에만).
resource "google_secret_manager_secret_iam_member" "airflow_news_db_ml_reader" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.news_db_ml_reader_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.ml_pipeline_sa_member
}

# --- BigQuery 결과 빠른 읽기(Storage Read API) -------------------------------
# feast_materialize가 원천 표 조회 결과를 Arrow로 받을 때 BigQuery Storage Read API를 쓴다
# (google-cloud-bigquery의 to_arrow → create_read_session). 이 호출은 프로젝트 수준의
# bigquery.readsessions.create 권한이 필요하고, dataEditor·jobUser에는 들어 있지 않다.
# 11/25 첫 전체 적재가 이 권한이 없어 403(PermissionDenied)으로 실패했다.
# 역할에는 읽기 세션 생성만 들어 있고, 어느 표를 읽을지는 데이터셋 권한(dataEditor)이 정한다.
resource "google_project_iam_member" "airflow_bq_read_session" {
  project = var.project_id
  role    = "roles/bigquery.readSessionUser"
  member  = local.ml_pipeline_sa_member
}
