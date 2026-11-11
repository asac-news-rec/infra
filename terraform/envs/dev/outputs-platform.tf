output "gke_cluster_name" {
  description = "GKE 클러스터 이름."
  value       = google_container_cluster.main.name
}

output "gke_zone" {
  description = "GKE 클러스터가 있는 구역(get-credentials에 필요)."
  value       = google_container_cluster.main.location
}

output "dockerhub_mirror_path" {
  description = "Docker Hub 복사본 저장소 주소(Helm values의 image.repository 앞부분)."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.dockerhub_mirror.repository_id}"
}

output "bastion_name" {
  description = "배스천 VM 이름."
  value       = google_compute_instance.bastion.name
}

output "bastion_external_ip" {
  description = "배스천의 고정 외부 IP. apt 등 인터넷 접속용이며 GKE 관리 주소 허용과는 무관하다."
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
