# Terraform 상태를 GCS 버킷에 저장한다.
# 버킷 이름은 프로젝트마다 다르므로 코드에 쓰지 않고 init 때 넘긴다(README 참고).
terraform {
  backend "gcs" {
    prefix = "envs/dev"
  }
}
