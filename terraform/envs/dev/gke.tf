# GKE Autopilot 클러스터. 노드(서버)를 직접 관리하지 않고, 파드가 요청한 CPU·메모리만큼만 과금된다.
# 제어면(관리 주소)은 공개 주소를 쓰되 "허용한 IP"만 접근할 수 있다(배스천 + 필요 시 추가 IP).
# 완전 비공개(private)로 바꾸는 것은 후속 결정이다(plan/ 참고).
resource "google_container_cluster" "main" {
  project  = var.project_id
  name     = "${var.name_prefix}-gke"
  location = var.region

  enable_autopilot = true

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.main.id

  # 파드·서비스용 IP 대역은 GKE가 자동으로 잡는다.
  ip_allocation_policy {}

  release_channel {
    channel = "REGULAR"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "${google_compute_address.bastion.address}/32"
      display_name = "bastion"
    }

    dynamic "cidr_blocks" {
      for_each = var.extra_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "extra-${cidr_blocks.key}"
      }
    }
  }

  resource_labels = local.labels

  deletion_protection = var.gke_deletion_protection

  depends_on = [google_project_service.platform_apis]
}
