# 배스천 서버: 팀원이 GKE 안으로 들어가는 통로. 작은 VM 1대.
# GKE 관리 주소는 비공개라서 VPC 안(이 VM이 있는 서브넷)에서만 접속된다.
# 임시 외부 IP는 NAT 없이 시작 스크립트가 apt로 kubectl을 설치하기 위한 것이다. 허용 목록에 등록하지 않으므로 고정할 필요가 없고,
# VM을 중지하면 IP도 함께 반환되어 IP 요금이 나오지 않는다(켤 때마다 주소가 바뀐다).
# SSH는 IAP로만 들어오고(방화벽 참고), 로그인은 구글 계정(OS Login)으로 한다. 키 파일은 쓰지 않는다.

resource "google_service_account" "bastion" {
  project      = var.project_id
  account_id   = "bastion"
  display_name = "Bastion VM"
}

# 배스천이 GKE 안에서 kubectl로 작업할 수 있는 권한.
resource "google_project_iam_member" "bastion_gke" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.bastion.email}"
}

resource "google_compute_instance" "bastion" {
  project      = var.project_id
  name         = "${var.name_prefix}-bastion"
  zone         = "${var.region}-a"
  machine_type = "e2-micro"
  tags         = ["bastion"]
  labels       = local.labels

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id

    # 임시 외부 IP(비어 있는 access_config). 고정 IP 리소스는 쓰지 않는다.
    access_config {}
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # kubectl과 GKE 인증 도구를 처음 켤 때 설치한다. 실패해도 VM은 동작하며, 그때는 README의 수동 설치를 따른다.
  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    apt-get update
    apt-get install -y kubectl google-cloud-cli-gke-gcloud-auth-plugin
  SCRIPT

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}

# 접속할 사람에게 필요한 권한 3가지. 모두 이 배스천 VM과 서비스 계정에만 적용한다.
resource "google_compute_instance_iam_member" "bastion_os_login" {
  for_each = toset(var.bastion_users)

  project       = var.project_id
  zone          = google_compute_instance.bastion.zone
  instance_name = google_compute_instance.bastion.name
  role          = "roles/compute.osLogin"
  member        = each.value
}

resource "google_iap_tunnel_instance_iam_member" "bastion_iap" {
  for_each = toset(var.bastion_users)

  project  = var.project_id
  zone     = google_compute_instance.bastion.zone
  instance = google_compute_instance.bastion.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value
}

# VM에 서비스 계정이 붙어 있으면 OS Login 사용자가 그 계정을 "사용"할 권한이 필요하다.
resource "google_service_account_iam_member" "bastion_user" {
  for_each = toset(var.bastion_users)

  service_account_id = google_service_account.bastion.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}
