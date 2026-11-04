# 플랫폼: 네트워크, GKE, 배스천, Cloud SQL

`apis-platform.tf`, `network.tf`, `gke.tf`, `bastion.tf`, `cloudsql.tf`와 `*-platform.tf`가 만드는 것입니다. 기본 리소스(버킷, 이미지 창고 등)는 `README.md`(PR #8)를 보세요.

## 만들어지는 것 (`plan`에서 확인)
리소스 개수는 `15 + 3 × (bastion_users에 적은 사람 수)`입니다. 사람이 1명이면 18개입니다.

| 파일 | 리소스 | 쉬운 설명 |
|---|---|---|
| `apis-platform.tf` | API 5개 | compute, container, iap, oslogin, sqladmin |
| `network.tf` | VPC, 서브넷, 방화벽 1개 | 우리 전용 네트워크. SSH는 IAP 대역에서만 허용 |
| `bastion.tf` | 고정 IP, 서비스 계정, VM, 권한들 | 팀원이 GKE에 들어가는 통로(작은 VM 1대) |
| `gke.tf` | GKE Autopilot 클러스터 1개 | Airflow, MLflow, 추론 서버, Valkey가 올라갈 곳. 제어면은 허용한 IP만 접근 |
| `cloudsql.tf` | Cloud SQL 인스턴스 + DB `newsdb` | 뉴스 DB. 가장 작은 사양, 삭제 방지, 매일 백업 |

## 설계 결정
- **GKE 제어면은 공개 주소 + 허용 IP만 접근**합니다(배스천 IP + 필요하면 내 IP). 완전 비공개로 바꾸는 것은 후속 결정입니다. 나중에 바꿀 수 있는지는 공식 문서로 확인이 필요합니다(**[확인 필요]**). 안 되면 클러스터를 코드로 다시 만들면 됩니다(`gke_deletion_protection = false`).
- **배스천**은 외부 IP를 가지지만 SSH 방화벽은 IAP 대역(35.235.240.0/20)에서만 열립니다. 로그인은 구글 계정(OS Login)이고 키 파일은 없습니다.
- **Cloud SQL**은 허용 네트워크를 하나도 열지 않아 직접 접속이 안 되고, Auth Proxy(구글 계정 인증, 암호화)로만 접속합니다. 비공개 IP로 바꾸는 것은 후속 결정입니다.
- **DB 비밀번호는 Terraform으로 만들지 않습니다.** 상태 파일에 평문으로 남기 때문입니다(아래 "DB 사용자 만들기").

## 변수 파일에 추가할 것 (terraform.tfvars, 커밋하지 않음)
```
bastion_users          = ["user:<접속할-구글-계정>"]
extra_authorized_cidrs = ["<내-공인-IP>/32"]
```
내 공인 IP는 `curl -s https://api.ipify.org`로 확인합니다. 집·학원 IP가 바뀌면 이 값을 고치고 다시 `apply`합니다.

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
내 컴퓨터(WSL)에서 접속하려면(내 IP가 허용된 경우):
```bash
sudo apt-get install -y kubectl google-cloud-cli-gke-gcloud-auth-plugin
gcloud container clusters get-credentials news-rec-gke --region asia-northeast3 --project <프로젝트-ID>
kubectl get nodes
```
배스천으로 접속하려면:
```bash
terraform output bastion_ssh_command
```
출력된 명령을 실행해 VM에 들어간 뒤 위의 `get-credentials`와 `kubectl`을 실행합니다.

## DB 사용자 만들기 (비밀번호는 코드에 쓰지 않음)
```bash
gcloud sql users create newsapp --instance=news-rec-pg --prompt-for-password
```
`--prompt-for-password` 옵션 지원 여부는 gcloud 버전에 따라 다릅니다(**[확인 필요]**). 비밀번호는 Secret Manager에 따로 보관합니다. 채팅과 레포에는 올리지 않습니다.

## 비용과 끄는 법 (공식 가격 계산기로 확인 필요)
- Autopilot은 파드가 없으면 컴퓨트 비용이 거의 없습니다. 클러스터 관리비는 결제 계정당 월 무료 크레딧이 한 개분을 상쇄한다고 알려져 있습니다(**[확인 필요]**).
- Cloud SQL(db-f1-micro)과 배스천(e2-micro)은 켜져 있는 동안 계속 과금됩니다.
- 배스천 중지: `gcloud compute instances stop news-rec-bastion --zone asia-northeast3-a`
- 클러스터 삭제: `terraform destroy -target=google_container_cluster.main` (워크로드가 없을 때만)
- Cloud SQL은 `deletion_protection`으로 보호됩니다. 지워야 하면 코드에서 값을 false로 바꾸고 apply한 뒤 destroy합니다.

## 문제가 생기면
| 증상 | 확인 |
|---|---|
| `Permission denied` / API가 꺼져 있음 | 방금 켠 API는 반영에 몇 분 걸립니다. 잠시 뒤 다시 `apply` |
| 배스천 SSH 거부 | `bastion_users`에 내 계정이 있는지, apply 했는지 확인 |
| `kubectl`이 시간 초과 | 내 공인 IP가 `extra_authorized_cidrs`에 있는지 확인(IP 변경 가능) |
| 이미 같은 이름의 Cloud SQL이 있다 | 삭제된 인스턴스 이름은 일정 기간 다시 쓸 수 없습니다. `name_prefix`를 바꾸거나 기다립니다 |
