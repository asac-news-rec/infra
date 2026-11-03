# 에이전트 프로젝트 참조

> Last Updated: 2026-11-03

프로젝트 구조, 폴더 책임, 팀 소유권을 빠르게 찾기 위한 문서입니다.
"X는 어디에 있는가?", "Y는 누가 소유하는가?" 질문에 답합니다.
상태 표기(**[현재]** / **[계획]** / **[미정]**)는 `CLAUDE.md`의 표기 규칙을 따릅니다.

## 이 문서를 볼 때

- 저장소 레이아웃과 폴더별 책임을 파악해야 할 때
- 새 compose 설정, Terraform 리소스, workflow를 추가할 위치를 정해야 할 때
- 팀 도메인 경계와 소유권을 확인해야 할 때

## 프로젝트 구조

### [현재] 지금 저장소에 있는 것

```
.
├── README.md
├── CLAUDE.md                 # 에이전트 진입 문서 (AGENTS.md는 이 파일의 symlink)
├── CONTRIBUTING.md           # 사람용 협업 규칙 (워크플로우 전체)
├── .claude/
│   └── docs/                 # 에이전트 상세 가이드 (.agents는 이 폴더의 symlink)
└── .github/
    ├── ISSUE_TEMPLATE/       # Issue Forms (feature/bug/experiment)
    ├── PULL_REQUEST_TEMPLATE.md
    └── workflows/
        ├── branch-name-policy.yml   # 브랜치 이름 검사
        └── claude.yml               # Claude Code PR 리뷰 (secret 등록 후 사용)
```

에이전트 호환 진입점으로 `AGENTS.md -> CLAUDE.md`, `.agents -> .claude`
symlink를 둡니다.

### [계획] 앞으로 만들 것 (경로와 이름은 바뀔 수 있음)

```
compose/                      # 팀 공용 로컬 개발 환경 (11/5 공유 목표)
├── docker-compose.yml
├── .env.example              # 환경변수 이름 목록 (실값은 .env에 두고 커밋 금지)
├── postgres/init.sql         # 뉴스 DB 등 초기화
├── gcs/                      # 가짜 GCS의 초기 폴더 구조
└── airflow/dags/             # 로컬 Airflow DAG 마운트 위치

terraform/                    # GCP 계정 발급 후 시작
├── modules/                  # gke, gcs, bigquery, cloudsql, network 재사용 묶음
└── envs/dev/                 # 계정별 변수(project id 등). 계정 교체 시 여기만 바꿈

helm/                         # GKE 안에 올릴 앱 (Terraform 이후)
├── airflow/
├── mlflow/
├── valkey/                   # Valkey를 직접 설치하는 경우 [미정]
├── inference-server/
└── logging-server/           # 로깅 서버를 GKE에 둘 경우 [미정]

docs/                         # 운영 문서가 필요해지면 생성
```

## Team Ownership & Domains

> 역할 분담은 팀 확정 전입니다. 확정되면 이 표를 갱신합니다.

| 도메인 | 팀원 | 책임 | 주요 저장소·경로 |
|---|---|---|---|
| **인프라** | 장주현 (`josiah113366-sketch`) | compose, Terraform, Helm, GitHub 자동화, 계정 교체 대비 | `infra` |
| **데이터 처리·모델** | 신윤모 (`yoonmo335`) | Airflow DAG, BigQuery SQL, 피처, 학습, 청사진 | `data-ml-pipeline`, `blueprint` |
| **뉴스 서버·기사** | 태원 (`taewonkim2`) | 뉴스 백엔드, 기사 생성, 뉴스 DB | `backend` |
| **프론트·행동 수집** | 김세호 (`hosose`) | 화면, 이벤트 수집, 로깅 서버 | `frontend` |
| **추론 서버** | [미정] | 서버 틀·배포(인프라 담당 제안) / 점수 계산(ML 담당 제안) | [미정] |

이 저장소의 주 담당은 인프라 도메인입니다. 인프라 변경이 다른 도메인(수집
파이프라인, DAG, 모델 서빙)에 영향을 주면 해당 담당자를 리뷰어로 포함합니다.

- PR Assignee 기본값: PR 작성자 본인
- 머지에는 팀원 2명의 approve가 필요합니다.

## Ownership Boundaries

### `compose/` [계획]
- **책임:** 팀원 누구나 같은 환경에서 개발할 수 있는 로컬 개발 환경 한 벌.
- **패턴:** 서비스 설정은 `docker-compose.yml`, 값은 `.env`, 값의 목록은
  `.env.example`에 둡니다. 팀원 서버의 이미지 이름은 환경변수로 받아 이미지를
  바꿔 끼울 수 있게 합니다.
- **주의:** `.env`는 커밋하지 않습니다. 데이터가 있는 컨테이너(Postgres 등)는
  볼륨을 사용하며, 볼륨을 지우는 명령은 사용자 확인 후에만 실행합니다.

### `terraform/` [계획]
- **책임:** 클라우드 리소스 정의(클러스터, 버킷, 데이터셋, DB, IAM).
- **패턴:** 리소스 종류별로 `.tf` 파일을 분리합니다. 계정 교체에 대비해
  project id, 버킷 이름 같은 값은 변수로 받습니다.
- **주의:** GCP 계정 발급 전에는 시작하지 않습니다.

### `helm/` [계획]
- **책임:** 클러스터 안에 올릴 앱(Airflow, MLflow, 추론 서버 등)의 설정.
- **주의:** Terraform으로 클러스터를 만든 뒤에 사용합니다.

### `.github/workflows/`
- **책임:** 검증(브랜치 이름 검사)과 리뷰 자동화만 담습니다.
- **주의:** workflow `permissions`는 최소 권한으로 유지하고, 클라우드 인증은
  service account key 대신 OIDC/WIF를 우선합니다 **[계획]**.

### `docs/` [계획]
- **책임:** 운영 문서와 계획 문서. 동작·명령어·정책이 바뀌면 같은 PR에서
  관련 문서를 갱신합니다.

## Technical Stack

### 확정 (멘토 10/28, 10/31 기준)
- **로컬:** Docker Compose가 개발 환경 역할을 합니다.
- **클라우드:** GCP를 우선으로 합니다 (필수는 아니며 크레딧 때문입니다).
  GKE(Airflow 직접 설치, 추론 서버, MLflow), Cloud Run(외부에 노출되는
  프론트·백엔드), Cloud SQL(뉴스 DB), GCS(원본 로그·모델·이미지),
  BigQuery(정제·피처).
- **IaC:** Terraform(클라우드 리소스) + Helm(클러스터 안의 앱).
- **계정 교체:** 약 6주 뒤 계정이 교체될 수 있어, Terraform으로 똑같이
  재생성할 수 있어야 합니다.

### 미정
- GCP 계정 발급 시점과 프로젝트 구성
- Valkey(Redis 계열)를 매니지드로 쓸지 직접 설치할지
- 로깅 서버 실행 위치(Cloud Run / GKE)
- GKE 운영 모드와 노드 수
- GCP API 활성화 방식(코드로 / 수동). 계정 발급 후 Terraform을 시작할 때 정합니다.

## Key Extension Rules

1. **영역 확인:** 변경이 로컬 개발 환경(compose)인지, 클라우드(Terraform/Helm)인지
   먼저 판단합니다.
2. **올바른 위치에 배치:** 위 구조의 폴더 책임을 따릅니다. 새 영역이면 이
   문서의 구조도를 함께 갱신합니다.
3. **변수·예시 갱신:** 새 환경변수는 `.env.example`에, 새 Terraform 변수는
   `terraform.tfvars.example`에 함께 추가합니다.
4. **검증:** 영역별 검증 명령(`CLAUDE.md` 검증 절)을 통과시킵니다.
5. **설계 결정 기록:** 아키텍처에 영향이 있으면 계획을 남기고, 완료 후 핵심
   결정은 관련 `.claude/docs/` 가이드를 갱신합니다.

## Verification Checklist

- [ ] 변경이 올바른 폴더에 있고 폴더 책임과 맞다.
- [ ] 새 변수가 `.env.example` 또는 `terraform.tfvars.example`에 반영되어 있다.
- [ ] `git diff --check`와 영역별 검증을 통과했다.
- [ ] 비용·리전·IAM 영향이 PR에 설명되어 있다.
- [ ] 동작·설정이 바뀌었으면 문서를 갱신했다.
