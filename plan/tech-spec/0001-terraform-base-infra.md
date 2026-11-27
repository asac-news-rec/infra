# 테크 스펙 0001: Terraform으로 만드는 기본 인프라

> 상태: 1~2단계 구현·적용 완료(bootstrap #6, foundation #8, platform #12), Helm(Valkey) 설치·확인 후 클러스터와 함께 삭제됨(#14, 검토 대기), GKE는 11/6 삭제 후 재구성 예정(#21) | 작성일: 2026-11-04 | 갱신: 2026-11-06 | 관련 이슈: #5, #7, #9, #11, #13, #21
> **먼저 볼 곳**: 요약 → 계획의 4~5절(무엇을, 어떤 순서로) → 마일스톤.
> 1단계(상태 버킷, 원본 로그·모델 버킷, 이미지 창고, 서비스 계정)와 2단계(전용 네트워크, 배스천, GKE, Cloud SQL)는 코드로 만들어 `apply`까지 마쳤습니다(11/5). 11/5 멘토 피드백에 따라 GKE는 **비공개 + 직접 관리형(노드 풀)**으로 다시 만들기로 해서 11/6에 삭제했고, Cloud SQL은 비용 절감을 위해 중지했습니다(방법과 금액은 7, 8절). 콘솔과 가격표를 직접 볼 수 없어 **[확인 필요]** 표시가 붙은 곳은 실행 전에 확인해야 합니다.
> **주의: 재구성(#21)이 끝나기 전까지 `terraform apply`를 하지 않는다.** main의 `gke.tf`가 옛 구성(공개 주소의 Autopilot)이라 apply하면 지운 클러스터가 다시 만들어지고 Cloud SQL이 다시 켜진다(7절).

## 요약 (Summary)
GCP 프로젝트 `final-project`(ID `final-project-513508`)에 팀이 쓸 **바탕**(상태 저장 버킷, 로그·모델·이미지 버킷, 도커 이미지 창고, 서비스 계정)을 Terraform 코드로 만든다. 2단계로 **전용 네트워크, 배스천, GKE 클러스터, DB(Cloud SQL)**도 만들었다(11/5). GKE는 멘토 피드백(비공개, 직접 관리형)에 따라 재구성한다. 프로젝트 ID와 이름은 모두 변수로 두어 계정을 바꿔도 같은 코드로 재현한다.

## 배경 (Background)
- 멘토(11/3): 구글 계정과 서비스 계정을 준비하고 Terraform으로 GCP를 구성하라고 했다. 목요일(11/5)까지 GCP·Terraform·DB·Helm 세팅이 필요하다.
- 크레딧은 약 $300(₩402,977, 2027-02-01까지)이고 다 쓰면 카드로 청구된다. 크레딧을 다 쓰면 계정을 바꿔야 하므로 **재현 가능한 코드**가 필요하다.
- 코드로 남기면 누가 무엇을 바꿨는지 PR에 기록되고 포트폴리오 근거가 된다.

## 목표 (Goals)
- 로컬에서 `terraform plan → apply`를 성공시켜 기본 리소스를 만든다.
- 프로젝트 ID, 리전, 이름을 바꾸는 것만으로 다른 프로젝트에도 만들 수 있다.
- 서비스 계정 키 파일 없이 동작한다.
- 모든 변경이 이슈, PR, 2명 승인을 거친다.

## 목표가 아닌 것 (Non-Goals)
- 앱 배포(프론트, 뉴스 백엔드, 로깅 서버): GitHub Actions가 한다(ADR-001).
- Argo CD, ELK, Prometheus·Grafana: 멘토 지시(11/3)로 필요해질 때 진행한다. 배스천은 PR #12, Helm(Valkey)은 PR #14에서 다뤘다.
- 예산 알림: 윤모 님이 이미 설정했다(결제 계정 권한은 윤모 님).
- 환경 분리(dev/prod): 하나(`dev`)만 쓴다.
- BigQuery 데이터셋 설계: 윤모 님과 협의 후 별도로.

## 계획 (Plan)

### 1. 전제와 정해야 할 것
| 항목 | 값 | 상태 |
|---|---|---|
| 프로젝트 | `final-project-513508` | 확인됨. 장주현 Owner |
| 리전 | `asia-northeast3` (서울) | 확정(서울에 적용 완료) |
| 환경 | `dev` 하나 | 확정(적용 완료) |
| 인증 | 처음에는 내 구글 로그인, 이후 서비스 계정 가장 | 4절 |
| 상태 저장 | GCS 버킷 | 확정 방향 (멘토) |
| Cloud SQL | PostgreSQL 16, db-f1-micro | 생성·적용 완료(#12). 11/6부터 비용 절감을 위해 중지(STOPPED) |
| GKE | Autopilot으로 생성(#12) → 비공개 + 직접 관리형으로 재구성 예정 | 11/5 멘토 피드백, 11/6 삭제 |

### 2. 폴더 구조 (단순하게 시작)
```
terraform/
  bootstrap/        # 처음 한 번만. 상태 저장 버킷과 필수 API 켜기
  envs/dev/         # 실제 환경. 여기서 plan·apply
    versions.tf     # Terraform·provider 버전 고정
    backend.tf      # 상태를 GCS에 저장하는 설정
    providers.tf    # provider 설정
    variables.tf    # 변수 (project_id, region, name_prefix)
    apis.tf         # 필요한 API 켜기
    storage.tf      # 버킷들
    registry.tf     # 도커 이미지 창고
    iam.tf          # 서비스 계정과 권한
    outputs.tf      # 결과 값 (버킷 이름 등)
    apis-platform.tf, variables-platform.tf, outputs-platform.tf   # 2단계(플랫폼)용 API, 변수, 결과 값
    network.tf      # 전용 VPC, 서브넷, IAP SSH 방화벽
    bastion.tf      # 배스천 VM, 고정 IP, 접속 권한
    gke.tf          # GKE 클러스터 (재구성 예정, #21)
    cloudsql.tf     # Cloud SQL (PostgreSQL)
    README.md, README-platform.md   # 실행 방법
    terraform.tfvars.example   # 값이 비어 있는 예시
plan/               # 이 문서 같은 설계 문서 (tech-spec/, adr/)
```
- 처음에는 `modules/` 폴더를 만들지 않는다. 리소스가 적어서 `envs/dev` 안에 파일을 나눠 두면 충분하다.
- Cloud SQL이나 GKE처럼 크고 재사용할 것이 생기면 그때 `modules/`로 옮긴다.

### 3. 무엇을 만드나

**1단계 (지금, 비용 거의 없음)**
| 리소스 | 쉬운 설명 | 왜 필요한가 |
|---|---|---|
| API 활성화 | GCP는 서비스마다 "사용 켜기"가 필요 | 안 켜면 뒤의 생성이 실패 |
| 상태 버킷 `<project>-tfstate` | Terraform의 "지금 무엇이 만들어졌나" 장부 | 팀 공유, 분실 방지. 삭제 방지와 버전 관리 |
| 원본 로그 버킷 | 로깅 서버가 JSONL.gz를 저장 | Airflow가 읽음 |
| 모델 파일 버킷 | 학습한 모델 보관 | MLflow와 추론 서버가 참조 |
| 이미지 버킷 | 기사 이미지 보관 | DB에는 경로만 저장(태원 님 협의 후 생성) |
| Artifact Registry | 도커 이미지 창고 | Actions가 올리고 Cloud Run·GKE가 가져감 |
| 서비스 계정 | 프로그램 전용 계정 | 프로그램마다 필요한 권한만 부여 |

**서비스 계정과 권한 (필요한 곳에만 필요한 만큼)**
| 서비스 계정 | 하는 일 | 권한 |
|---|---|---|
| `logging-server` | 원본 로그 버킷에 쓰기 | 그 버킷에 객체 생성만 |
| `github-actions` | 이미지 올리기(현재), Cloud Run 배포(나중, WIF와 함께) | Artifact Registry 쓰기(`roles/artifactregistry.writer`, 현재). Cloud Run 배포 권한은 나중에 추가 |
| `inference` (나중) | 모델 읽기 | 모델 버킷 읽기만 |
| `airflow` (나중) | 로그 읽기, BigQuery 쓰기 | 로그 버킷 읽기, BigQuery 작업 |

**2단계 (PR #12, 적용 완료 11/5)**
| 리소스 | 상태 |
|---|---|
| 전용 VPC, 서브넷, IAP 대역 SSH 방화벽 | 생성 완료 |
| 배스천 VM(e2-micro), 고정 IP, 서비스 계정(`container.developer`만), 접속자 권한 | 생성 완료. 구글 계정(OS Login)과 IAP 터널로만 접속, 접속·kubectl 확인(11/5) |
| Cloud SQL (PostgreSQL 16, db-f1-micro) | 생성 완료. 허용 네트워크 없음(Auth Proxy 전용), 삭제 방지, 매일 백업. DB 사용자 생성과 Auth Proxy 접속 확인은 **아직** |
| GKE 클러스터 | Autopilot으로 생성했으나 멘토 피드백(11/5: 클러스터는 비공개, 배스천이 유일한 문, Autopilot 말고 직접 관리)에 따라 **11/6에 삭제**. 재구성은 이슈 #21로 다룬다 |

**3단계 (Helm, PR #14)**: Valkey 공식 차트(0.12.1, 앱 9.1.3)를 단독 구성으로 설치하고 확인했다(11/5). 클러스터를 삭제해 현재는 없으며, 클러스터를 다시 만든 뒤 같은 값으로 설치한다.

### 4. 인증 방식
Terraform은 프로그램이라서 GCP에 "누구인지"를 증명해야 리소스를 만들 수 있다.
1. **처음**: 내 구글 계정으로 로그인한다(`gcloud auth application-default login`). 자격 증명 파일은 내 컴퓨터의 홈 폴더에 생기고 레포에는 올라가지 않는다.
2. **그다음(후속 PR)**: `terraform` 전용 서비스 계정을 만들고 내 계정이 **가장(impersonation)**해서 실행한다.
3. 서비스 계정 **키 파일(JSON)은 만들지 않는다**(유출 위험).

### 5. 이름과 변수 규칙
- `project_id`(`final-project-513508`), `region`(`asia-northeast3`), `name_prefix`(`news-rec`)를 변수로 둔다.
- 버킷 이름은 전 세계에서 유일해야 해서 `<project_id>-이름`으로 만든다.
- 진짜 값이 들어간 `terraform.tfvars`는 커밋하지 않고 `terraform.tfvars.example`만 올린다.
- 모든 리소스에 `labels`(예: `project=news-rec`)를 달아 비용을 구분한다.

### 6. 실행 흐름
```bash
terraform fmt -check          # 코드 모양 점검
terraform init                # provider 받기, 상태 저장소 연결
terraform validate            # 문법·참조 오류 점검
terraform plan -out=tfplan    # 무엇이 만들어지고 바뀌고 지워질지 미리 보기
terraform apply tfplan        # plan 그대로 실제 생성
```
- `plan`에서 `destroy`, `replace`(지우고 다시 만들기)가 있으면 멈추고 확인한다.
- `plan` 출력은 PR에 요약해서 붙인다(비밀값이 섞였는지 확인).
- `terraform`(1.17.1)과 `gcloud`는 설치·로그인을 마쳤고 `apply`까지 실행했다(11/4).

### 7. 현재 상태와 `apply` 규칙 (2026-11-06)
11/6에 비용 절감과 재구성 준비를 위해 아래 세 가지를 **코드 변경 없이** 실행했다.

| 대상 | 한 일 | 방법 | 결과 |
|---|---|---|---|
| GKE 클러스터 | 삭제 | `terraform destroy -target=google_container_cluster.main` | `Destroy complete! Resources: 1 destroyed` |
| Cloud SQL | 중지 | `gcloud sql instances patch news-rec-pg --activation-policy=NEVER` | 상태 `STOPPED`, 정책 `NEVER` |
| 배스천 VM | 중지 | `gcloud compute instances stop news-rec-bastion` | `TERMINATED` |

- Terraform 코드(main)는 그대로다. `gke.tf`는 옛 Autopilot 구성이고 `cloudsql.tf`에는 `activation_policy`가 없다.
- 그래서 지금 `terraform plan`(11/6) 결과는 **`Plan: 1 to add, 1 to change, 0 to destroy.`**다. `google_container_cluster.main`이 **다시 만들어지고**, `google_sql_database_instance.news`가 **제자리 변경**(다시 켜기)된다.
- **규칙: 재구성(#21)이 끝나기 전까지 `terraform apply`를 하지 않는다.** apply하면 비공개로 바꾸기로 한 공개 주소의 Autopilot 클러스터가 다시 만들어지고 DB가 켜진다. 불가피하면 `-target`으로 대상을 한정하고 plan을 먼저 확인한다.
- 재구성 이슈는 #21(GKE를 비공개 + 직접 관리형으로)이다.
- DB를 켜야 할 때(사용자 생성, Auth Proxy 확인)는 `gcloud sql instances patch news-rec-pg --activation-policy=ALWAYS`로 켜고, 끝나면 다시 중지한다.

### 8. 비용 (어림, 공식 가격 계산기 확인 전)
| 항목 | 내용 |
|---|---|
| 계획 시점 어림(PR #12) | 24시간 켜 둘 때 월 약 $90 안팎: GKE 관리비 월 약 $73, Cloud SQL 월 약 $8~10, 배스천 월 약 $7와 고정 IP |
| GKE 관리비 | 월 무료 혜택($74.40, 한 구역 또는 Autopilot 클러스터 1개분)으로 차감되는 것을 11/6 청구서로 확인(₩4,070 전액 차감). 상쇄되면 월 고정비는 약 $17 |
| 지금까지 실제(11/6) | 체험 크레딧 사용 약 ₩1,649(잔액 약 ₩401,328) |
| 중지·삭제 뒤 남는 비용 | 배스천 디스크와 예약된 고정 IP(월 약 $7~8로 어림, 대부분 고정 IP), Cloud SQL 디스크 10GB(월 $1~2). 합 월 약 ₩1만~1.5만 **[확인 필요]** |
- 모든 금액은 어림이며 공식 가격 계산기로 확인하지 않았다. 재구성(#21)에서 노드 크기·개수와 함께 계산기로 확인한다.

## 이외 고려 사항 (Other Considerations)
- **서비스 계정 키 파일**: 쉽지만 유출 위험이 커서 쓰지 않는다.
- **`modules/` 처음부터 만들기**: 리소스가 적은 지금은 과하다고 보고 보류한다.
- **환경 분리(dev/prod)**: 실제 사용자가 없는 프로젝트라 비용만 늘어서 하지 않는다.
- **콘솔에서 손으로 만들기**: 빠르지만 기록과 재현이 안 된다(ADR-005).
- **로깅 서버 저장 방식**(ADR-003)이 바뀌면 원본 로그 버킷과 서비스 계정 권한이 달라질 수 있다. 현재는 팀이 비교 중이다.
- **GKE 접근 방식**: 처음에는 비용과 복잡도를 줄이려고 공개 주소 + 허용 IP로 열었으나, 멘토 피드백(11/5)으로 비공개 + 배스천 터널링으로 바꾼다. 비공개 노드는 인터넷에 직접 나가지 못해 NAT 또는 이미지 복사(Artifact Registry)가 필요하다.

## 마일스톤 (Milestones)
| PR | 내용 | apply |
|---|---|---|
| ① #4 | `.gitignore` | 없음 |
| ② #10 | `plan/` 폴더, 템플릿, 이 스펙, ADR | 없음 (리뷰 수정 중) |
| ③ #6 | `terraform/bootstrap` (상태 버킷, API) | 완료 |
| ④ #8 | `terraform/envs/dev` (버킷, 이미지 창고, 서비스 계정) | 완료 |
| ⑤ #12 | 전용 네트워크, 배스천, GKE, Cloud SQL | 완료(11/5). GKE는 11/6 삭제 |
| ⑥ #14 | Helm으로 Valkey 설치 값 | 설치·확인 완료(11/5), 클러스터 삭제로 현재는 없음. 재구성 후 재설치. PR 검토 대기 |
| ⑦ #21 | GKE를 비공개 + 직접 관리형으로 재구성 | 예정(이슈 #21 등록). 끝나기 전까지 `apply` 금지(7절) |

- 목표였던 11/5(목) 20시 멘토링 전 ①~④ 머지와 apply는 달성했고, ⑤도 apply까지 마쳤다.
- ③을 먼저 로컬에서 실행한 뒤 ④가 GCS 상태 저장소를 가리켜야 하므로 **순서가 중요하다.**

## 이해 체크 (멘토 역질문 대비)
| 질문 | 답 |
|---|---|
| Terraform이 뭐고 왜 쓰나요? | 클라우드 리소스를 코드로 적어 만드는 도구. 같은 코드로 다른 프로젝트에도 재현되고 변경 기록이 남는다. |
| 상태 파일은 뭔가요? | "지금 무엇이 만들어져 있나"를 적은 장부. 잃어버리면 코드와 실제가 어긋나서 GCS에 두고 공유한다. |
| 왜 bootstrap을 따로 두나요? | 상태를 저장할 버킷도 먼저 있어야 하는데 그 버킷을 만들 때는 저장할 곳이 아직 없어서, 처음 한 번만 로컬 상태로 만든다. |
| 서비스 계정을 왜 나누나요? | 하나가 뚫려도 피해가 그 권한 범위로 한정되도록 필요한 권한만 따로 준다. |
| 왜 키 파일을 안 만드나요? | 유출되면 비밀번호처럼 위험하고 레포에 올라가기 쉽다. |
| 프로젝트 ID를 왜 변수로 두나요? | 크레딧이 끝나 계정을 바꿀 때 한 값만 바꿔 다시 만들기 위해서. |
| DB와 클러스터는 지금 어떤 상태인가요? | 둘 다 11/5에 만들었다. 비용 절감을 위해 11/6에 Cloud SQL은 중지, GKE는 삭제했다. GKE는 멘토 피드백에 따라 비공개 + 직접 관리형으로 다시 만든다. |
| 앱 배포가 왜 Terraform이 아닌가요? | 앱은 자주 바뀌어 Actions가 배포하고 Terraform은 바뀌지 않는 환경(버킷, 권한)을 맡는다(멘토 지시). |
| `plan`에서 무엇을 보나요? | destroy·replace, 이름과 리전, 비용이 큰 리소스가 끼었는지. |

## 확인 필요
- GKE 재구성(#21: 비공개, 직접 관리형)의 노드 크기·개수와 비용, 비공개 노드의 이미지 받기(NAT 또는 Artifact Registry 복사) (공식 문서, 가격 계산기)
- DB 분리(같은 서버에서 백엔드용과 Airflow·MLflow용 DB를 나눔)와 DB 사용자·접속 확인
- 이미지 버킷 이름과 경로 규칙 (태원 님)
- 로깅 서버 세부 조율 (세호 님)
