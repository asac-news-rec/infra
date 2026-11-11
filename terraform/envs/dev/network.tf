# 팀 전용 가상 네트워크(VPC)와 서브넷. 기본(default) 네트워크는 쓰지 않는다.
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.platform_apis]
}

resource "google_compute_subnetwork" "main" {
  project                  = var.project_id
  name                     = "${var.name_prefix}-subnet"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true

  # GKE 파드·서비스가 쓰는 IP 대역. 서브넷 본 대역(10.10.0.0/24)과 겹치지 않게 잡는다.
  secondary_ip_range {
    range_name    = local.gke_pods_range_name
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = local.gke_services_range_name
    ip_cidr_range = "10.30.0.0/20"
  }
}

# 배스천으로 들어오는 SSH는 IAP(구글 인증 터널)의 IP 대역에서만 허용한다. 인터넷 전체에는 열지 않는다.
resource "google_compute_firewall" "allow_iap_ssh" {
  project   = var.project_id
  name      = "${var.name_prefix}-allow-iap-ssh"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
}
