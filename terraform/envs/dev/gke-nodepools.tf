# GKE 노드 풀: 노드(서버 VM)를 직접 정의한다.
# - fixed 풀: 항상 떠 있어야 하는 것(Valkey, MLflow, 추론 서버, 필요하면 Airflow)이 올라간다.
# - worker 풀: 학습 같은 작업용. 일이 없으면 0개로 줄고, 일이 생기면 자동으로 늘어난다.
# 노드는 켜져 있는 시간만큼 과금된다. 평소에는 fixed 풀을 0개로 줄여 둔다(README-platform.md 참고).

# 노드 VM이 쓰는 서비스 계정. 기본 계정(권한이 넓음) 대신 필요한 권한만 준다.
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "gke-nodes"
  display_name = "GKE nodes"
}

locals {
  # 로그·지표를 보내는 데 필요한 최소 권한.
  gke_node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ]
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset(local.gke_node_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# 노드가 이미지를 받을 수 있다(우리 이미지 창고와 Docker Hub 복사본, 읽기만).
resource "google_artifact_registry_repository_iam_member" "gke_nodes_images" {
  project    = var.project_id
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_artifact_registry_repository_iam_member" "gke_nodes_mirror" {
  project    = var.project_id
  location   = google_artifact_registry_repository.dockerhub_mirror.location
  repository = google_artifact_registry_repository.dockerhub_mirror.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_node_pool" "fixed" {
  project  = var.project_id
  name     = "fixed"
  cluster  = google_container_cluster.main.name
  location = google_container_cluster.main.location

  # 만들 때의 노드 수. 평소에는 gcloud로 줄이고 늘리므로 Terraform은 이 값을 이후에 무시한다.
  # 0으로 만드는 것이 거부되면 1로 바꿔서 만든다([확인 필요]).
  node_count = var.gke_fixed_node_count

  lifecycle {
    ignore_changes = [node_count]
  }

  node_config {
    machine_type    = var.gke_fixed_machine_type
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_nodes.email
    # cloud-platform 범위는 넓어 보이지만, 실제 권한은 전용 서비스 계정(gke-nodes)에 부여한 IAM 역할(로그·지표 쓰기, 이미지 읽기)이 한도가 된다.
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels       = merge(local.labels, { pool = "fixed" })

    # 파드가 GCP에 접속할 때 Workload Identity를 쓰도록 노드의 메타데이터 서버를 GKE 것으로 바꾼다.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "google_container_node_pool" "worker" {
  project  = var.project_id
  name     = "worker"
  cluster  = google_container_cluster.main.name
  location = google_container_cluster.main.location

  # 일이 없으면 0개, 일이 생기면 최대 gke_worker_max_nodes개까지 자동으로 늘어난다.
  initial_node_count = 0

  autoscaling {
    min_node_count  = 0
    max_node_count  = var.gke_worker_max_nodes
    location_policy = "ANY"
  }

  node_config {
    machine_type    = var.gke_worker_machine_type
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_nodes.email
    # cloud-platform 범위는 넓어 보이지만, 실제 권한은 전용 서비스 계정(gke-nodes)에 부여한 IAM 역할(로그·지표 쓰기, 이미지 읽기)이 한도가 된다.
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels       = merge(local.labels, { pool = "worker" })

    # Spot VM: 가격이 낮은 대신 GCP가 언제든 회수할 수 있다. 다시 시도해도 되는 작업에만 쓴다.
    spot = true

    # 이 풀에는 "worker" 표시를 한 파드만 올라간다(고정 서비스가 섞여 올라오지 않게).
    taint {
      key    = "workload"
      value  = "worker"
      effect = "NO_SCHEDULE"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
