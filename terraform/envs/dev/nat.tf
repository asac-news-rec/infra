# 비공개 노드와 파드가 인터넷으로 "나가는" 연결만 허용하는 Cloud NAT.
# 밖에서 안으로 들어오는 연결은 열리지 않는다(접속은 계속 배스천뿐).
# 필요한 이유: Airflow git sync(GitHub), OpenRouter 호출, Docker Hub가 아닌 곳의 이미지.
# 비용: 켜져 있는 동안 시간당 요금과 외부로 나가는 데이터 요금이 붙는다(가격 계산기로 확인).
resource "google_compute_router" "nat" {
  project = var.project_id
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "main" {
  project = var.project_id
  name    = "${var.name_prefix}-nat"
  region  = var.region
  router  = google_compute_router.nat.name

  # NAT 주소는 구글이 자동으로 할당한다.
  nat_ip_allocate_option = "AUTO_ONLY"

  # 우리 서브넷의 본 대역과 파드·서비스 보조 대역 모두 밖으로 나갈 수 있게 한다.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.main.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
