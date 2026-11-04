output "gke_cluster_name" {
  description = "GKE 클러스터 이름."
  value       = google_container_cluster.main.name
}

output "bastion_name" {
  description = "배스천 VM 이름."
  value       = google_compute_instance.bastion.name
}

output "bastion_external_ip" {
  description = "배스천의 고정 외부 IP(GKE 제어면이 허용하는 주소)."
  value       = google_compute_address.bastion.address
}

output "bastion_ssh_command" {
  description = "IAP로 배스천에 접속하는 명령."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone ${google_compute_instance.bastion.zone} --tunnel-through-iap --project ${var.project_id}"
}

output "cloudsql_connection_name" {
  description = "Cloud SQL Auth Proxy가 쓰는 연결 이름."
  value       = google_sql_database_instance.news.connection_name
}
