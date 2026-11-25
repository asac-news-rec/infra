# 같은 Cloud SQL 인스턴스(news-rec-pg) 안에서 서비스별로 데이터베이스를 분리한다(멘토 11/5, 11/15·16).
# - behavior_logs: 행동 로그 수집(logging_api)과 Airflow 내보내기 DAG(logging_airflow)가 쓴다.
# - airflow: Airflow 메타데이터. 지금은 GKE 안 PostgreSQL이고, 전환은 별도 작업이다.
# - mlflow: MLflow 기록 저장소. 전환은 별도 작업이다.
# DB 계정과 비밀번호는 Terraform으로 만들지 않는다(README-platform.md 참고).

resource "google_sql_database" "behavior_logs" {
  project  = var.project_id
  instance = google_sql_database_instance.news.name
  name     = "behavior_logs"
}

resource "google_sql_database" "airflow" {
  project  = var.project_id
  instance = google_sql_database_instance.news.name
  name     = "airflow"
}

resource "google_sql_database" "mlflow" {
  project  = var.project_id
  instance = google_sql_database_instance.news.name
  name     = "mlflow"
}
