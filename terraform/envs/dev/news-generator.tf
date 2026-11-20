# 뉴스 생성기(Airflow KubernetesPodOperator 작업)가 쓰는 비밀값과 버킷 권한 (이슈 #59).
# 서비스 계정 airflow는 이슈 #37(PR #45)이 만든다. #51과 같은 방식으로 이름으로 참조하므로
# #45 머지 전에도 plan이 가능하다(계정은 -target apply로 이미 존재).
# 쿠버네티스 계정 airflow/airflow-task의 Workload Identity 연결은 #45가 만든다.
locals {
  airflow_sa_email = "airflow@${var.project_id}.iam.gserviceaccount.com"

  # 생성한 썸네일을 저장하는 버킷. 11/10에 gcloud로 만들어 코드 밖에 있다(import는 후속 이슈).
  news_thumbnails_bucket = "${var.project_id}-news-thumbnails"
  news_thumbnails_prefix = "images/"
}

# --- Secret Manager ---------------------------------------------------------
# 값은 코드와 state에 넣지 않는다. 껍데기(Secret)만 만들고, 값(version)은 사람이 gcloud로 넣는다.
resource "google_secret_manager_secret" "openrouter_api_key" {
  project   = var.project_id
  secret_id = "openrouter-api-key"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = merge(local.labels, { purpose = "news-generator" })
}

# 이 Secret의 값을 읽을 수 있는 것은 airflow 계정뿐이다(그 Secret에만).
resource "google_secret_manager_secret_iam_member" "airflow_openrouter" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.openrouter_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.airflow_sa_email}"
}

# news-db-password는 11/10에 gcloud로 만든 기존 Secret이다. 값은 바꾸지 않고 읽기 권한만 붙인다.
resource "google_secret_manager_secret_iam_member" "airflow_news_db_password" {
  project   = var.project_id
  secret_id = "news-db-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.airflow_sa_email}"
}

# --- 썸네일 버킷 권한 ---------------------------------------------------------
# 객체 생성과 조회만, images/ 경로에서만 허용한다. 목록 조회와 삭제는 주지 않는다.
# 주의: 같은 이름의 객체를 다시 쓰려면 삭제 권한이 필요하다(덮어쓰기는 create+delete).
#       생성기가 같은 파일명을 다시 쓰는지는 이슈 #59에서 확인 중이다.
resource "google_project_iam_custom_role" "airflow_thumbnails" {
  project     = var.project_id
  role_id     = "${replace(var.name_prefix, "-", "_")}_airflow_thumbnails"
  title       = "Airflow thumbnails writer"
  description = "썸네일 버킷의 객체를 만들고 조회할 수 있다. 뉴스 생성기용."

  permissions = [
    "storage.objects.create",
    "storage.objects.get",
  ]
}

resource "google_storage_bucket_iam_member" "airflow_thumbnails" {
  bucket = local.news_thumbnails_bucket
  role   = google_project_iam_custom_role.airflow_thumbnails.id
  member = "serviceAccount:${local.airflow_sa_email}"

  condition {
    title       = "images-prefix-only"
    description = "images/ 경로의 객체만"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${local.news_thumbnails_bucket}/objects/${local.news_thumbnails_prefix}\")"
  }
}
