# 추론 서버(data-ml-pipeline serving/, PR #24) dev 배포에 필요한 GCP 자원 (이슈 #76).
# 추론 서버 Pod는 쿠버네티스 계정 inference/inference-server → GCP 서비스 계정 inference-server로 실행된다.
# inference-server 계정과 feast/ 읽기 권한은 #57(feast-registry.tf)이 만든다. 머지 전이라 이메일·이름 문자열로 참조한다.
# 쿠버네티스 쪽(Namespace, Deployment, 내부 LB Service)은 k8s/inference-server/inference-server.yaml.
locals {
  inference_sa_email     = "inference-server@${var.project_id}.iam.gserviceaccount.com"
  inference_sa_member    = "serviceAccount:${local.inference_sa_email}"
  inference_namespace    = "inference"
  inference_ksa          = "inference-server"
  inference_model_bucket = "${var.project_id}-model-artifacts"
  inference_model_prefix = "models/pctr/"

  # models/pctr/ 경로의 객체만 대상으로 하는 조건.
  inference_model_condition = "resource.name.startsWith(\"projects/_/buckets/${local.inference_model_bucket}/objects/${local.inference_model_prefix}\")"
}

variable "inference_model_uploaders" {
  description = "추론 서버 이미지와 모델 파일(models/pctr/)을 올리는 사람의 구글 계정 목록. 코드에 적지 않고 로컬 terraform.tfvars로 받는다."
  type        = list(string)
  default     = []

  # 값을 넣지 않고 apply하면 이미 준 권한이 조용히 삭제된다. 빈 목록을 막는다.
  validation {
    condition     = length(var.inference_model_uploaders) > 0
    error_message = "inference_model_uploaders가 비어 있습니다. terraform.tfvars에 업로드할 구글 계정을 넣어 주세요."
  }
}

# --- Workload Identity: 쿠버네티스 계정 → GCP 계정 ------------------------------
# inference 네임스페이스의 inference-server 쿠버네티스 계정만 이 GCP 계정으로 행동할 수 있다. 키 파일은 없다.
resource "google_service_account_iam_member" "inference_workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.inference_sa_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.inference_namespace}/${local.inference_ksa}]"
}

# --- 모델 파일 읽기 -------------------------------------------------------------
# 추론 서버가 시작할 때 gs://<model-artifacts>/models/pctr/lgbm.txt를 읽는다(MODEL_PATH). 이 경로만 읽기.
# feast/registry.pb 읽기는 #57의 feast_registry_inference가 준다.
resource "google_storage_bucket_iam_member" "inference_model_reader" {
  bucket = local.inference_model_bucket
  role   = "roles/storage.objectViewer"
  member = local.inference_sa_member

  condition {
    title       = "pctr-model-prefix-only"
    description = "models/pctr/ 경로의 객체만"
    expression  = local.inference_model_condition
  }
}

# --- 모델 파일 올리기(사람) -----------------------------------------------------
# 학습한 모델을 models/pctr/에 올린다. 같은 이름으로 덮어쓰려면 삭제 권한이 필요해 objectUser를 쓴다(이 경로만).
resource "google_storage_bucket_iam_member" "inference_model_uploaders" {
  for_each = toset(var.inference_model_uploaders)

  bucket = local.inference_model_bucket
  role   = "roles/storage.objectUser"
  member = "user:${each.value}"

  condition {
    title       = "pctr-model-prefix-only"
    description = "models/pctr/ 경로의 객체만"
    expression  = local.inference_model_condition
  }
}

# --- 이미지 올리기(사람) --------------------------------------------------------
# news-rec 이미지 창고에 추론 서버 이미지를 올린다. writer에는 읽기도 들어 있다.
# 창고 단위 권한이라 다른 이미지에도 올릴 수 있다. 태그를 덮어쓰지 않는 규칙(docker/ml-work.md)을 따른다.
resource "google_artifact_registry_repository_iam_member" "inference_image_pushers" {
  for_each = toset(var.inference_model_uploaders)

  project    = var.project_id
  location   = var.region
  repository = var.name_prefix
  role       = "roles/artifactregistry.writer"
  member     = "user:${each.value}"
}

# --- 내부 고정 IP ----------------------------------------------------------------
# 내부 부하 분산기(VPC 안에서만 보임)가 쓸 주소를 미리 잡아 둔다. Service를 다시 만들어도 주소가 바뀌지 않아,
# 뉴스 WAS(Cloud Run, VPC 연결)가 이 주소를 설정에 고정해 둘 수 있다. 외부 공개 주소가 아니다.
resource "google_compute_address" "inference_ilb" {
  project      = var.project_id
  name         = "${var.name_prefix}-inference-ilb"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = "projects/${var.project_id}/regions/${var.region}/subnetworks/${var.name_prefix}-subnet"
  description  = "추론 서버 내부 부하 분산기 주소 (이슈 #76)"
}

output "inference_ilb_ip" {
  description = "추론 서버 내부 부하 분산기 주소. 뉴스 WAS가 http://<이 주소>:8080/v1/rank 로 부른다."
  value       = google_compute_address.inference_ilb.address
}
