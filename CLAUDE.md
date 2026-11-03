# AI 코딩 에이전트 작업 지침

> Version: 0.1.0 | Last Updated: 2026-11-03

이 문서는 Claude Code 등 AI 코딩 에이전트가 이 저장소에서 작업할 때의 기본
진입점입니다. 필수 규칙은 짧게 유지하고, 상세 가이드는 `.claude/docs/`를
참조합니다.

## 표기 규칙

이 저장소는 아직 구축 중입니다. 문서가 실제 상태와 어긋나지 않도록 각 내용에
상태를 표기합니다:

- **[현재]** 지금 저장소에 실제로 있는 것
- **[계획]** 만들 예정인 것. 경로·이름은 바뀔 수 있습니다
- **[미정]** 아직 팀이나 멘토가 정하지 않은 것

**[계획]·[미정] 항목을 이미 있는 것처럼 다루지 않습니다.** 존재하지 않는
파일이나 폴더를 찾거나, 문서에 적혀 있다는 이유로 임의로 만들지 않습니다.

## 언어 원칙

에이전트 응답, PR 코멘트, 리뷰 요약, 구현 노트는 한국어 격식체를 사용합니다.
사용자가 명시적으로 요청하는 경우에만 다른 언어를 사용합니다.

## 규칙 우선순위

규칙이 충돌하면 다음 순서로 적용합니다:

1. 사용자의 명시적 요청
2. `CLAUDE.md` 및 `AGENTS.md` symlink
3. `.claude/docs/` 하위 가이드
4. `README.md`, `CONTRIBUTING.md`, 기타 저장소 문서

같은 수준이면 더 구체적이고 더 최근에 갱신된 규칙을 우선합니다.

## 문서 탐색 기준

비자명한 변경을 하기 전에 가장 관련 있는 가이드를 먼저 확인합니다:

| 요청 유형 | 먼저 볼 문서 | 다음 문서 |
| --- | --- | --- |
| 프로젝트 구조·소유권 | `.claude/docs/agent-project-reference.md` | `.claude/docs/architecture-overview.md` |
| Terraform 스타일·구성 [계획] | `.claude/docs/agent-terraform-reference.md` | `.claude/docs/architecture-overview.md` |
| 워크플로우, 커밋, PR | `.claude/docs/agent-workflow-reference.md` | `.claude/docs/agent-prohibitions.md` |
| 보안, 시크릿, IAM | `.claude/docs/agent-security-guidelines.md` | `.claude/docs/agent-prohibitions.md` |

각 문서는 현재 구현과 계획을 구분해 표기합니다.

## 프로젝트 맥락

- **프로젝트:** ASAC 파이널 프로젝트(뉴스 추천 시스템). 뉴스 서비스를 만들고,
  사용자 행동 로그를 모아, 클릭 확률(CTR)을 예측하는 모델을 학습·서빙하는
  전체 데이터 흐름을 한 바퀴 돌리는 것이 목표입니다. 모델 성능보다 **전체
  데이터 흐름과 ML 워크플로를 설명할 수 있는 것**이 중요합니다.
- **이 저장소(`asac-news-rec/infra`):** 로컬 개발 환경(Docker Compose)과
  클라우드 인프라(Terraform, Helm), GitHub 운영 자동화를 코드로 관리합니다.
- **[현재]** README, 에이전트 하네스 문서(`CLAUDE.md`, `.claude/docs/`),
  협업 규칙(`CONTRIBUTING.md`), `.github/`의 이슈·PR 템플릿과 workflow 2개
  (`branch-name-policy.yml`, `claude.yml`)만 있습니다.
- **[계획]** `compose/`(팀 공용 로컬 개발 환경, 11/5 공유 목표), `terraform/`과
  `helm/`(GCP 계정 발급 후 시작). 구조는 `.claude/docs/agent-project-reference.md`를
  참조합니다.
- **[미정]** 클라우드 계정 발급 시점, 클라우드 제품 구성의 일부(Valkey를 매니지드로
  쓸지 직접 설치할지, 로깅 서버 실행 위치 등). 계정은 약 6주 뒤 교체될 수 있어
  Terraform으로 똑같이 재생성할 수 있어야 합니다.
- 저장소는 5개입니다:

| 저장소 | 내용 |
| --- | --- |
| `infra` | 이 저장소. 로컬 개발 환경, 클라우드 인프라 |
| `backend` | 뉴스 백엔드 서버 |
| `frontend` | 화면과 행동 이벤트 수집 |
| `data-ml-pipeline` | Airflow DAG, 피처, 학습 |
| `blueprint` | 전체 청사진(설계 문서) |

- 애플리케이션 기능 구현은 이 저장소 범위가 아닙니다. 서비스 코드는
  `backend`·`frontend`, 데이터·ML 코드는 `data-ml-pipeline`에서 다룹니다.

## 핵심 규칙

- 코드가 변경되는 작업은 반드시 이슈를 먼저 발행하고, 그 이슈의
  `Create a branch`로 브랜치를 생성합니다(이슈-브랜치 자동 연결). 상세는
  `.claude/docs/agent-workflow-reference.md`를 참조합니다.
- 새 추상화보다 기존 저장소 패턴을 우선합니다. 아직 패턴이 없는 영역은
  `agent-project-reference.md`의 계획 구조를 따릅니다.
- 구조 변경과 동작 변경(리소스 변경)은 분리합니다.
- 실제 클라우드 리소스 생성/삭제(`terraform apply`/`destroy`)는 사용자가 명확히
  요청했을 때만 수행합니다.
- GitHub 원격에 영향을 주는 작업(issue/PR 생성·수정, push, label, Project,
  Ruleset)은 실행 전에 사용자에게 먼저 확인받습니다.
- `.env`, Terraform state, 실제 `.tfvars`, service account key, API 키 같은
  secret 값은 커밋하지 않습니다. 공유가 필요하면 값이 비어 있는 예시
  파일(`.env.example` 등)만 커밋합니다.
- IAM은 최소 권한 원칙을 따르고, dev 리소스는 최소 비용 기준으로 시작합니다.
  예산이 정해져 있으므로 켜 두는 동안 과금되는 리소스는 쓰지 않을 때 줄입니다.
- 동작, 명령어, 설정, 운영 방식이 바뀌면 문서를 갱신합니다.
- 커밋 메시지, PR 본문, 이슈 본문은 작성 전에 반드시 `.github/`의 템플릿
  (`PULL_REQUEST_TEMPLATE.md`, `ISSUE_TEMPLATE/*.yml`)과
  `CONTRIBUTING.md`의 컨벤션을 읽고 그 구조를 그대로 따릅니다. 임의 형식을
  사용하지 않습니다.
- 모든 작업은 관련 `.md` 문서(README, 가이드 문서)의 갱신을 같은
  변경(PR)에 포함합니다.
- 보안을 항상 최우선으로 검토합니다: secret/state/tfvars 노출, IAM 권한 확대,
  외부 노출 리소스(public IP/LB/Ingress) 생성 여부를 커밋 전에 diff에서
  확인합니다.
- 학습용 환경이라도 실제 회사 운영 기준으로 작업합니다: 이슈→브랜치→
  Draft PR→리뷰→squash merge 워크플로우를 생략하지 않고, 변경마다 검증·롤백
  방법·비용 영향을 기록합니다.

## 로컬 개발

**[계획]** 팀 공용 로컬 개발 환경은 `compose/`에 Docker Compose로 만듭니다.
작업이 끝나면 아래 명령과 경로를 실제 값으로 갱신합니다.

```bash
# 예정: 설정 파일 문법 검사
docker compose -f compose/docker-compose.yml config
```

- 포함할 부품: Postgres, Airflow, Valkey, MLflow, 가짜 GCS(fake-gcs-server).
  백엔드·프론트·로깅·추론 서버는 각 담당자가 이미지를 만들 때까지 자리만
  둡니다.
- 환경변수는 `compose/.env`에 두고 커밋하지 않으며, `compose/.env.example`만
  공유합니다.
- `terraform plan`은 실제 GCP project id와 인증이 준비된 뒤 실행합니다.
  로컬 `terraform.tfvars`와 state/plan 파일은 커밋하지 않습니다. **[계획]**

## 계획 먼저

비자명한 변경(신규 클라우드 리소스, IAM/네트워크 변경, 대규모 다중 파일 수정,
workflow 권한 변경)은 구현 전에 계획을 작성합니다.

- 계획은 이슈 본문이나 PR 설명에 적거나, 길면 `docs/` 아래 문서로 남깁니다.
  (`docs/`는 필요할 때 만듭니다.)
- 계획에는 목적, 변경 범위, 검증 방법, 롤백 방법, 비용 영향을 적습니다.
- 새로 만들기보다 기존 관련 문서의 갱신을 우선합니다.
- 작업 완료 후 현재 운영 절차는 해당 가이드 문서에 반영합니다.

문서만 수정하거나 범위가 좁은 변경은 스레드 내 짧은 계획으로 진행할 수
있습니다.

## 검증

변경을 증명하는 가장 좁은 검증부터 수행하고, 공유 환경이나 운영 워크플로우에
영향이 있으면 범위를 넓힙니다.

현재 항상 실행하는 검증:

```bash
git diff --check
```

변경 영역별 검증:

- GitHub workflow 변경: 로컬에 `actionlint`가 있으면 함께 사용합니다.
- Docker Compose 변경 **[계획]**: `docker compose config`로 문법을 확인하고,
  실제로 `up`이 되는지 확인합니다.
- Terraform 변경 **[계획]**: `fmt -check`, `validate`를 통과시킵니다.

## 리뷰 기준

PR 리뷰 시 심각도 순으로 구체적 발견 사항을 먼저 제시합니다. 중점 사항:

- 정확성 버그와 기존 동작의 의도치 않은 변경 (리소스 교체·삭제 유발)
- 시크릿·자격 증명·state 노출 위험
- IAM 권한 확대와 최소 권한 원칙 위반
- 비용, quota, 리전 영향
- 삭제/교체/권한 확대 변경의 롤백 방법 누락
- workflow `permissions`와 GitHub secret 처리

구체적 이슈는 인라인 코멘트로, 요약 코멘트는 짧게 유지합니다.
