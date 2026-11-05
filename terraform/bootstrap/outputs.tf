output "tfstate_bucket" {
  description = "Terraform 상태를 저장하는 버킷 이름. envs/dev의 backend 설정에 쓴다."
  value       = google_storage_bucket.tfstate.name
}
