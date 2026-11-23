# 플랫폼: 네트워크, GKE, 배스천, Cloud SQL

`apis-platform.tf`, `network.tf`, `gke.tf`, `gke-nodepools.tf`, `bastion.tf`, `cloudsql.tf`와 `*-platform.tf`가 만드는 것입니다. 기본 리소스(버킷, 이미지 창고 등)는 `README.md`(PR #8)를 보세요.

## 만들어지는 것 (`plan`에서 확인)
이 문서의 처음 구성(PR #12)은 `15 + 3 × (bastion_users에 적은 사람 수)`개였습니다. 비공개 Standard 재구성(이슈 #21)으로 노드 풀, 노드 서비스 계정과 권한, Docker Hub 복사본 저장소가 추가되었고 GKE 클러스터는 새로 생성됩니다(옛 Autopilot 클러스터는 11/6에 삭제해 상태 파일에도 없으므로 `plan`에서 교체가 아니라 추가로 나타납니다). 정확한 개수는 `plan`에서 확인합니다.

| 파일 | 리소스 | 쉬운 설명 |
|---|---|---|
| `apis-platform.tf` | API 5개 | compute, container, iap, oslogin, sqladmin |
| `network.tf` | VPC, 서브넷, 방화벽 1개 | 우리 전용 네트워크. SSH는 IAP 대역에서만 허용 |
| `bastion.tf` | 서비스 계정, VM(임시 외부 IP), 권한들 | 팀원이 GKE에 들어가는 통로(작은 VM 1대) |
| `gke.tf` | GKE Standard 클러스터 1개(비공개, 한 구역) | Valkey, MLflow, 추론 서버(필요하면 Airflow)가 올라갈 곳. 관리 주소에 공개 IP가 없고 배스천에서만 접속 |
| `gke-nodepools.tf` | 노드 풀 2개(`fixed`, `worker`), 노드용 서비스 계정과 권한 | `fixed`는 항상 떠 있어야 하는 것, `worker`는 작업용(Spot, 일이 없으면 0개) |
| `registry.tf` | (추가) `dockerhub-mirror` 저장소 | 비공개 노드가 인터넷 없이 Docker Hub 이미지를 받는 복사본 |
| `cloudsql.tf` | Cloud SQL 인스턴스 + DB `newsdb` | 뉴스 DB. 가장 작은 사양, 삭제 방지, 매일 백업 |

## 설계 결정
- **GKE는 비공개 Standard 클러스터**입니다(멘토 11/5, 이슈 #21). 노드와 관리 주소 모두 공개 IP가 없고, 관리 주소에는 VPC 서브넷(배스천이 있는 곳) 안에서만 접속됩니다. 내 컴퓨터에서 직접 `kubectl`은 되지 않으며 **배스천을 거쳐야** 합니다.
- **한 구역(zonal)** 입니다(`asia-northeast3-a`). 구역은 클러스터를 만든 뒤 바꿀 수 없습니다. **Dataplane V2**(NetworkPolicy가 동작하는 네트워크 방식)도 만들 때만 고를 수 있다고 알고 있습니다(**[확인 필요]**).
- **이미지는 Artifact Registry의 Docker Hub 복사본**에서 받습니다(NAT 없음). Docker Hub가 아닌 곳(`registry.k8s.io`, `quay.io` 등)의 이미지는 받지 못할 수 있으므로 Helm 차트를 설치하기 전에 `helm template`로 이미지 목록을 확인합니다(**[확인 필요]**).
- **파드는 Workload Identity로 GCP에 접속**합니다(키 파일 없음). 파드별 서비스 계정 연결은 서비스를 올릴 때 추가합니다.
- **배스천**은 임시 외부 IP를 가지지만 SSH 방화벽은 IAP 대역(35.235.240.0/20)에서만 열립니다. 로그인은 구글 계정(OS Login)이고 키 파일은 없습니다. 외부 IP는 NAT 없이 `apt` 등 인터넷을 쓰기 위한 것이며 GKE 접속 허용과는 무관합니다.
- **Cloud SQL**은 허용 네트워크를 하나도 열지 않아 직접 접속이 안 되고, Auth Proxy(구글 계정 인증, 암호화)로만 접속합니다. 비공개 IP로 바꾸는 것은 후속 결정입니다.
- **DB 비밀번호는 Terraform으로 만들지 않습니다.** 상태 파일에 평문으로 남기 때문입니다(아래 "DB 사용자 만들기").

## 변수 파일에 추가할 것 (terraform.tfvars, 커밋하지 않음)
```
bastion_users = ["user:<접속할-구글-계정>"]
```
GKE 관리 주소는 비공개라서 내 공인 IP를 허용 목록에 넣지 않습니다(이전 `extra_authorized_cidrs` 변수는 없어졌습니다).

## 실행 순서
```bash
terraform init -backend-config="bucket=<프로젝트-ID>-tfstate"
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```
- GKE 클러스터 생성은 시간이 걸립니다(보통 10분 안팎, 제 추정). Cloud SQL도 몇 분 걸립니다.
- 배스천 VM 시작 스크립트가 `kubectl`과 GKE 인증 도구를 설치합니다. 실패하면 VM에 접속해 `sudo apt-get install -y kubectl google-cloud-cli-gke-gcloud-auth-plugin`을 실행합니다.
- 배스천의 부팅 이미지는 Debian 13입니다. Debian 12 이미지(커널 6.1.0-55, 2026-11-14 빌드)에서 VM이 반복해서 멈춰 바꿨습니다(이슈 #46). 이미지를 바꾸면 VM이 교체되고, **VM이 교체되면 접속 권한(OS Login, IAP)이 사라집니다**(VM에 붙은 IAM 정책이라 VM과 함께 지워지며 11/17에 두 번 확인했습니다). 교체 뒤에는 아래 명령으로 다시 만듭니다: `terraform apply -target=google_compute_instance_iam_member.bastion_os_login -target=google_iap_tunnel_instance_iam_member.bastion_iap`. VM이 교체될 때 이 두 바인딩도 같이 다시 만들어지게 하는 근본 해결(`replace_triggered_by`)은 후속으로 합니다. 현재 VM의 이미지는 `debian-13-trixie-v20261116`입니다(2026-11-19 `gcloud compute disks describe`로 확인). 같은 멈춤이 재발하면 `image`를 이 이름으로 고정합니다. 패밀리(`debian-13`)를 유지하는 것은 새 VM이 보안 패치가 된 최신 빌드를 받게 하기 위해서이고, 고정하면 패치가 늦어집니다.

## 클러스터에 접속하기
클러스터는 비공개라서 **배스천에서만** 접속합니다.
```bash
terraform output bastion_ssh_command
```
출력된 명령을 실행해 VM에 들어간 뒤(배스천은 꺼져 있을 수 있으니 먼저 `gcloud compute instances start news-rec-bastion --zone asia-northeast3-a`) 아래를 실행합니다.
```bash
gcloud container clusters get-credentials news-rec-gke --zone asia-northeast3-a --internal-ip --project <프로젝트-ID>
kubectl get namespaces
```
- `--internal-ip`는 비공개 관리 주소(내부 주소)로 접속하라는 뜻입니다.
- 노드가 0개이면 `kubectl get nodes`는 비어 있는 것이 정상입니다. 접속이 되는지는 `kubectl get namespaces`로 확인합니다.

## DB 사용자 만들기 (비밀번호는 코드에 쓰지 않음)
```bash
gcloud sql users create newsapp --instance=news-rec-pg --prompt-for-password
```
`--prompt-for-password` 옵션 지원 여부는 gcloud 버전에 따라 다릅니다(**[확인 필요]**). 비밀번호는 Secret Manager에 따로 보관합니다. 채팅과 레포에는 올리지 않습니다.

## 비용과 끄는 법 (공식 가격 계산기로 확인 필요)
- **노드(VM)는 켜져 있는 시간만큼 과금**됩니다. 노드가 0개이면 노드 요금이 없습니다. 한 구역(zonal) 클러스터의 관리비는 월 무료 혜택 대상으로 알려져 있습니다(**[확인 필요]**).
- Cloud SQL(db-f1-micro)과 배스천(e2-micro)은 켜져 있는 동안 계속 과금됩니다. 배스천의 외부 IP는 **임시 IP**라서 VM을 중지하면 IP 요금도 나오지 않습니다(고정 IP는 중지해도 요금이 나오기 때문에 쓰지 않습니다).
- 배스천 중지: `gcloud compute instances stop news-rec-bastion --zone asia-northeast3-a`
- **노드 켜기와 끄기**(고정 풀): 코드는 `node_count` 변경을 무시하므로 `gcloud`로 조정합니다. 상태(Airflow·MLflow 기록, 모델)는 클러스터 밖(Cloud SQL, GCS, BigQuery)에 두는 것이 전제입니다.
  - 끄기: `gcloud container clusters resize news-rec-gke --node-pool fixed --num-nodes 0 --zone asia-northeast3-a`
  - 켜기: `gcloud container clusters resize news-rec-gke --node-pool fixed --num-nodes 2 --zone asia-northeast3-a`
  - 작업용 `worker` 풀은 자동으로 늘고 줄어서(0~`gke_worker_max_nodes`) 따로 조정하지 않습니다.
- 클러스터 삭제: `terraform destroy -target=google_container_cluster.main` (몇 주 이상 안 쓸 때만. 노드 풀도 함께 지워집니다)
- Cloud SQL은 `deletion_protection`으로 보호됩니다. 지워야 하면 코드에서 값을 false로 바꾸고 apply한 뒤 destroy합니다.

## 문제가 생기면
| 증상 | 확인 |
|---|---|
| `Permission denied` / API가 꺼져 있음 | 방금 켠 API는 반영에 몇 분 걸립니다. 잠시 뒤 다시 `apply` |
| 배스천 SSH 거부 | `bastion_users`에 내 계정이 있는지, apply 했는지 확인 |
| `kubectl`이 시간 초과 | 내 컴퓨터가 아니라 **배스천 안에서** 실행하는지, `--internal-ip` 옵션을 붙였는지 확인 |
| 파드가 `ImagePullBackOff` | 이미지가 `dockerhub-mirror`(또는 `news-rec`) 주소인지 확인. Docker Hub가 아닌 레지스트리의 이미지는 받지 못할 수 있음 |
| 이미 같은 이름의 Cloud SQL이 있다 | 삭제된 인스턴스 이름은 일정 기간 다시 쓸 수 없습니다. `name_prefix`를 바꾸거나 기다립니다 |

## Feast registry와 BigQuery 권한 (이슈 #57)
`feast-registry.tf`와 `storage.tf`의 수명 규칙이 만듭니다.
- **registry 위치**: `<프로젝트-ID>-model-artifacts` 버킷의 `feast/registry.pb`입니다.
- **권한(모두 `feast/` 경로의 객체에 한정, 조건부 권한)**:
  - 로컬 `feast apply`를 실행하는 사람(변수 `feast_registry_users`): 읽기·쓰기(`roles/storage.objectUser`)
  - Airflow materialize 작업(서비스 계정 `airflow`): 읽기·쓰기(`roles/storage.objectUser`). 파드가 이 권한을 쓰려면 `airflow-task` 연결(PR #45)이 먼저 필요합니다.
  - 추론 서버(새 서비스 계정 `inference-server`): 읽기만(`roles/storage.objectViewer`). Workload Identity 연결은 추론 서버를 올릴 때 추가합니다.
  - 조건이 객체 이름에 걸려 있어서, 경로를 알고 있는 객체의 읽기·쓰기만 됩니다. 목록 조회(`ls`)는 이 조건과 맞지 않아 막힐 수 있습니다(미확인).
- **버킷 메타데이터 조회**: Feast 0.68.0 GCS registry는 읽기·쓰기 전에 `get_bucket`을 불러 `storage.buckets.get`이 필요합니다. 객체 경로 조건(`feast/`)에는 걸리지 않으므로 이 권한 하나만 담은 커스텀 역할(`news_rec_bucket_metadata_reader`)을 위 세 주체에 조건 없이 줍니다. 버킷 설정만 보이고 객체 목록·내용은 보이지 않습니다(PR #64 리뷰, 11/23).
- **수명 규칙**: 이 버킷은 versioning이 켜져 있습니다(버킷 단위 설정). **`feast/` 경로에서** 덮어써서 밀려난 옛 버전만 **30일 뒤 자동 삭제**됩니다(registry를 이전 세대로 되돌리는 용도, `matches_prefix`). 프로젝트 종료(12/23)까지의 기간을 덮는 값입니다. MLflow 모델 파일(`mlflow/`) 등 다른 경로의 옛 버전은 지우지 않습니다. 처음(11/20)에는 버킷 전체에 걸었다가 PR #64 리뷰로 11/23에 좁혔습니다(그 사이 30일이 지나지 않아 지워진 것은 없음).
- **BigQuery**: 서비스 계정 `airflow`에 데이터셋 `dev_yoonmo`의 읽기·쓰기(`roles/bigquery.dataEditor`)와 프로젝트의 쿼리 실행 권한(`roles/bigquery.jobUser`)을 줍니다.
- **변수 파일에 추가할 것**(`terraform.tfvars`, 커밋하지 않음): `feast_registry_users = ["<구글-계정>"]`
- **적용**: state에 병합 전 PR의 리소스가 있어서 전체 plan은 사용하지 않고 `-target`으로 이 PR의 리소스만 plan·apply합니다.
- **롤백**: 이 PR을 되돌린 뒤 같은 `-target`으로 apply하면 권한이 사라집니다. 수명 규칙을 지우면 이후로는 옛 버전이 쌓입니다. 이미 삭제된 옛 버전은 복구되지 않습니다.
- **비용**: 서비스 계정과 IAM은 무료이고, 옛 버전은 KB 단위 파일이라 저장 비용은 사실상 없습니다.
