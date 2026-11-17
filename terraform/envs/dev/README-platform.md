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
| `cloudsql.tf` | Cloud SQL 인스턴스 + DB `newsdb` | 뉴스 DB. g1-small(공유 코어), 삭제 방지, 매일 백업 |
| `cloudsql-databases.tf` | DB `behavior_logs`, `airflow`, `mlflow` | 같은 인스턴스 안에서 서비스별 DB 분리(멘토 11/5). 계정은 Terraform 밖에서 생성 |
| `cloudsql-proxy.tf` | 서비스 계정 `cloudsql-proxy`, `roles/cloudsql.client`, Workload Identity 연결 | Auth Proxy용. 파드 매니페스트는 `k8s/cloud-sql-proxy/` |

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
PW="$(openssl rand -base64 24 | tr -d '/+=\n')"; printf '%s' "$PW" | gcloud secrets create logging-api-db-password --data-file=- && gcloud sql users create logging_api --instance=news-rec-pg --password="$PW"; unset PW
```
gcloud 592.0.0에는 `--prompt-for-password` 옵션이 없고 `--password`만 있습니다. 위 명령은 비밀번호를 화면에 출력하지 않고 Secret Manager에 먼저 저장한 뒤 같은 값으로 계정을 만듭니다. 비밀번호는 채팅과 레포에 올리지 않습니다.
- 계정: `logging_api`, `logging_airflow`(시크릿 `logging-api-db-password`, `logging-airflow-db-password`). 권한(GRANT)은 서비스 담당자가 검증한 SQL로 부여합니다.
- 접속: 클러스터 안에서 `cloud-sql-proxy.airflow.svc:5432`(Auth Proxy, `k8s/cloud-sql-proxy/`).
- `max_connections`는 g1-small에서 50입니다(2026-11-17 실측). 서비스별 연결 풀 크기를 합쳐 이 값을 넘지 않게 합니다.

## 비용과 끄는 법 (공식 가격 계산기로 확인 필요)
- **노드(VM)는 켜져 있는 시간만큼 과금**됩니다. 노드가 0개이면 노드 요금이 없습니다. 한 구역(zonal) 클러스터의 관리비는 월 무료 혜택 대상으로 알려져 있습니다(**[확인 필요]**).
- Cloud SQL(db-g1-small)과 배스천(e2-micro)은 켜져 있는 동안 계속 과금됩니다. 배스천의 외부 IP는 **임시 IP**라서 VM을 중지하면 IP 요금도 나오지 않습니다(고정 IP는 중지해도 요금이 나오기 때문에 쓰지 않습니다).
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
