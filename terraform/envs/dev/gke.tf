# GKE Standard 클러스터(비공개). 노드 풀은 gke-nodepools.tf에서 직접 정의한다.
#
# 이렇게 만드는 이유(멘토 11/5 피드백, 이슈 #21):
# - Autopilot이 아니라 Standard: 노드(서버)를 우리가 직접 정의하고 관리한다.
# - 비공개 노드 + 비공개 관리 주소: 인터넷에서 클러스터 관리 주소가 보이지 않는다.
#   관리(kubectl)는 같은 VPC 안의 배스천 VM에서만 한다.
# - 한 구역(zonal): 가장 단순하고 비용이 낮다. 구역은 클러스터를 만든 뒤 바꿀 수 없다.
# - Dataplane V2: NetworkPolicy(파드끼리 통신 제한)가 동작하는 네트워크 방식.
#   클러스터를 만들 때만 고를 수 있다고 알고 있다([확인 필요]).
# - Workload Identity: 파드가 키 파일 없이 GCP 서비스(BigQuery, GCS)에 접속하는 방식.
locals {
  gke_zone                = "${var.region}-a"
  gke_pods_range_name     = "gke-pods"
  gke_services_range_name = "gke-services"
}

resource "google_container_cluster" "main" {
  project  = var.project_id
  name     = "${var.name_prefix}-gke"
  location = local.gke_zone

  # 기본 노드 풀은 쓰지 않는다. 클러스터를 만들 때만 1개가 잠깐 생겼다가 지워지고,
  # 실제 노드 풀은 gke-nodepools.tf에서 정의한 것을 쓴다.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.main.id

  networking_mode   = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH"

  # 파드·서비스용 IP 대역(network.tf의 서브넷에 정의한 보조 대역).
  ip_allocation_policy {
    cluster_secondary_range_name  = local.gke_pods_range_name
    services_secondary_range_name = local.gke_services_range_name
  }

  # 노드와 관리 주소 모두 공개 IP가 없다. 노드는 인터넷에 직접 나가지 못하므로
  # 이미지는 Artifact Registry(registry.tf의 Docker Hub 복사본)에서 받는다.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.gke_master_cidr
  }

  # 관리 주소에는 우리 VPC 안(배스천이 있는 서브넷)에서만 접속할 수 있다.
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = google_compute_subnetwork.main.ip_cidr_range
      display_name = "vpc-subnet(bastion)"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  resource_labels = local.labels

  deletion_protection = var.gke_deletion_protection

  depends_on = [google_project_service.platform_apis]
}
