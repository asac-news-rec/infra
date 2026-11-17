# Cloud SQL Auth Proxy용 GCP 서비스 계정.
# 프록시 파드(airflow/cloud-sql-proxy)가 Workload Identity로 이 계정을 쓰고, 이 계정이 Cloud SQL에 접속할 자격(roles/cloudsql.client)을 가진다.
# DB 계정과 비밀번호는 여기서 만들지 않는다(README-platform.md 참고).

resource "google_service_account" "cloudsql_proxy" {
  project      = var.project_id
  account_id   = "cloudsql-proxy"
  display_name = "Cloud SQL Auth Proxy"
}

resource "google_project_iam_member" "cloudsql_proxy_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

resource "google_service_account_iam_member" "cloudsql_proxy_wif" {
  service_account_id = google_service_account.cloudsql_proxy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[airflow/cloud-sql-proxy]"
}

output "cloudsql_proxy_service_account" {
  value = google_service_account.cloudsql_proxy.email
}
