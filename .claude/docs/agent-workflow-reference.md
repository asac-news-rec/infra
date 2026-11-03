# 에이전트 워크플로우 참조

> Last Updated: 2026-11-03

GitHub 워크플로우 전체 가이드: Issue → Branch → Commit → PR → Review →
Merge. 모든 인프라 작업의 운영 표준입니다. 사람용 요약은
`CONTRIBUTING.md`에 있으며, 두 문서의 규칙은 항상 일치해야 합니다.

## 이 문서를 볼 때

- 새 인프라 작업을 시작하며 전체 워크플로우가 필요할 때
- 커밋 메시지나 PR 본문을 작성할 때
- PR이 워크플로우를 따르는지 검증할 때
- 브랜치 이름, 머지 방식이 헷갈릴 때

## 워크플로우 개요

```
Issue 생성
    ↓
Branch 생성 (이슈의 Create a branch, feat/이슈번호-설명)
    ↓
작업/검증 (git diff --check, 영역별 검증)
    ↓
Draft PR 생성 → 셀프 리뷰 및 설명 보강
    ↓
Ready for review 전환 → 에이전트 리뷰 자동 실행
    ↓
이해도 체크 inline 답변 → 팀원 리뷰 요청
    ↓
Approve 2명 + 대화 resolve → Squash Merge
    ↓
Issue 자동 close
```

## 에이전트 기본 규칙

- GitHub 원격에 영향을 주는 작업은 항상 사용자에게 먼저 확인받습니다:
  issue 생성·수정·close, label 변경, PR 생성·수정·merge, 원격 branch
  push·삭제, Project·Ruleset·Secrets 변경, remote URL 변경.
- 로컬 파일 읽기·수정은 진행해도 됩니다. GitHub에 반영하는 순간에만
  확인받습니다.
- 이슈·PR 기본값: **Assignee는 생성자 본인**으로 지정합니다. 웹에서는
  Assignees 옆의 `assign yourself`를, `gh` CLI를 쓸 때는 `--assignee @me`를
  사용합니다. (담당자를 자동으로 보정하는 workflow는 아직 없습니다.)
  label은 레포에 만들어 둔 것 중에서 성격에 맞춰 설정합니다
  (문서: `documentation`, 자동화: `chore` 등).

## 이슈 생성

**이슈를 만드는 경우:**
- Docker Compose(로컬 개발 환경) 구성 변경
- GCP 리소스 추가, 수정, 삭제 [계획]
- Terraform module, environment, backend 구성 변경 [계획]
- IAM 권한, service account, Secret Manager 설정 변경
- GitHub Actions workflow, Claude Review, OIDC, 배포 자동화 변경
- 비용, 리전, 보안, 운영 정책을 검증하는 실험
- 운영 문서 또는 runbook 추가·수정
- PR 리뷰 중 생긴 범위 밖 후속 작업

아주 작은 오타 수정은 바로 PR로 처리할 수 있습니다.

**Issue Forms** (`.github/ISSUE_TEMPLATE/`, 빈 이슈 생성 불가):

| Form | 제목 prefix | 자동 label | 필수 내용 |
|---|---|---|---|
| `feature.yml` | `[FEAT]` | `feature` | 목적, 작업 범위, 영향받는 인프라 영역, 완료 조건 |
| `bug.yml` | `[BUG]` | `bug` | 현상, 재현 방법, 기대 동작, 영향 영역, 환경·로그 |
| `experiment.yml` | `[EXP]` | `experiment` | 가설, 실험 대상, 판정 기준, 실험 설정, 결과 |

GitHub는 `form 선택 → label 자동 적용` 방식으로 동작합니다. 단, 레포에 같은
이름의 label이 만들어져 있어야 적용됩니다. 새 작업은 Issues 화면에서 form을
선택해 생성합니다.

## 브랜치 이름

**코드가 변경되는 작업은 반드시 이슈를 먼저 발행하고, 그 이슈에서 브랜치를
생성합니다.** GitHub 이슈 우측 `Development > Create a branch`를 사용하면
브랜치가 이슈에 자동 연결(`main` 기준 분기)되어, PR을 `main`으로 머지할 때
이슈 자동 close가 확실해집니다. 로컬에서 임의로 분기하는 대신 이슈에서 만든
브랜치를 체크아웃해 작업합니다.

**형식:** `<type>/<이슈번호>-<간략한-설명>`

**Type:** `feat/`, `fix/`, `exp/`, `docs/`, `refactor/`, `chore/`

- 영어 소문자, 숫자, 하이픈만 사용합니다.
- 이슈 번호를 반드시 포함합니다.
- 한 브랜치에는 하나의 주요 목적만 담습니다.
- Create a branch 대화상자의 기본 제안 이름은 사용하지 않고, 생성 전에 위 형식의
  영어 이름으로 직접 수정합니다.

```bash
# 이슈에서 Create a branch로 생성(예: feat/12-add-docker-compose) 후
git fetch origin
git switch feat/12-add-docker-compose
```

## 커밋 메시지

**형식:** `<type>: <한국어 설명>`

| type | 의미 |
|---|---|
| `feat` | 로컬 개발 환경, 클라우드 인프라 리소스, IaC, GitHub 자동화 추가 |
| `fix` | 인프라 설정, 권한, workflow, 문서 오류 수정 |
| `exp` | 구성 방식, 도구, 운영 자동화 실험 |
| `docs` | 운영 문서 추가 또는 수정 |
| `refactor` | 동작 변화 없는 IaC/문서/설정 구조 정리 |
| `chore` | 저장소 기본 설정, 관리 작업 |

**규칙:**
1. 한 커밋에는 하나의 논리적 변경만 담습니다.
2. 포맷 변경과 리소스 변경을 섞지 않습니다.
3. 제목은 현재형 동사로 50자 이내로 씁니다.
4. type은 위 6개만 사용합니다 (브랜치 이름 검사와 같은 목록입니다).

```text
feat: Postgres 컨테이너 설정 추가
fix: Airflow 포트 충돌 수정
docs: compose 실행 가이드 갱신
```

## PR 생성

**PR 생성 전 체크:**
- [ ] `git diff --check` 통과
- [ ] compose 변경이면 `docker compose config`와 실제 `up`을 확인했다 [계획]
- [ ] Terraform 변경이면 `fmt -check`와 `validate`를 통과했다 [계획]
- [ ] state, `.tfvars` 실값, service account key, secret이 포함되지 않았다
- [ ] 커밋 메시지가 컨벤션을 따른다
- [ ] Assignee를 생성자 본인으로 지정한다 (`gh` 사용 시 `--assignee @me`)
- [ ] 변경 성격에 맞는 label을 지정한다 (레포에 있는 label 중에서)

**PR 본문** (`.github/PULL_REQUEST_TEMPLATE.md` 사용):

```markdown
## 작업 내용
변경 요약

## 변경 사항
- 항목 1
- 항목 2

## 관련 이슈
Closes #12

## 리뷰어 참고사항
검증 명령·결과, IAM/비용/리전/롤백 영향
```

**좋은 PR의 조건:**
- 하나의 이슈를 해결합니다.
- 제목만 봐도 변경 목적이 드러납니다 (커밋 컨벤션과 동일 형식).
- 변경 사항이 bullet list로 정리되어 있습니다.
- IAM/비용/리전/롤백 영향이 설명되어 있습니다.
- 무관한 리팩터링과 리소스 변경을 섞지 않습니다.
- 리뷰 중 발견된 별도 작업은 새 이슈로 분리합니다.

**Draft vs Ready:**
- Draft: 작업 중이거나 이른 피드백이 필요할 때. 셀프 리뷰로 diff를
  처음부터 끝까지 읽고 설명을 보강한 뒤 Ready로 전환합니다.
- Ready: 정식 리뷰를 요청할 때. 에이전트 리뷰가 이때 실행됩니다.

## 리뷰와 승인

**머지 조건:**
- 팀원 **2명** approve
- 모든 conversation resolved
- CI status check 통과. 현재 자동 검사는 `branch-name-policy`입니다.
  required check로 지정하는 설정은 아래 "Branch protection"을 참고합니다.
- Ready for review 상태 (Draft는 approve가 있어도 merge 불가)

**리뷰어 확인 사항:**
- 이슈의 목적과 PR 변경이 일치하는가
- (클라우드 변경이라면) 대상 GCP 프로젝트, 리전, 리소스 이름이 명확한가
- IAM 권한이 최소 권한 원칙을 따르는가
- secret 값, service account key, Terraform state가 포함되지 않았는가
- 비용 영향과 quota 영향이 설명되어 있는가
- 삭제/교체/권한 확대 변경의 롤백 방법이 있는가
- workflow 권한과 GitHub secret 이름이 적절한가

**Claude 자동 리뷰:**
- PR이 처음 열리거나(`opened`) Ready for review로 전환되면
  (`ready_for_review`) 자동 실행됩니다. Draft에서는 실행되지 않습니다.
- 에이전트가 남긴 `이해도 확인:` inline comment에는 같은 스레드에서
  답변하고, 필요하면 로컬에서 검증한 뒤 resolve합니다.
- trivial, docs-only, formatting-only 변경에는 이해도 확인 comment를
  남기지 않는 정책입니다.
- **[준비 중]** repository secret `CLAUDE_CODE_OAUTH_TOKEN`을 등록하기 전에는
  이 검사가 실패로 표시될 수 있습니다. 머지를 막는 required check로
  지정하지 않습니다.

**Branch protection (`main`):** **[확인 필요]**
- 목표 규칙: 직접 push 금지, PR을 통한 변경만 허용, required status check
  `branch-name-policy`, approve 2명.
- 현재(2026-11-02 확인) `main`에는 보호 규칙이 설정되어 있지 않습니다. 비공개
  레포에서 규칙을 강제할 수 있는지는 GitHub의 Settings → Rules에서 확인하고,
  강제할 수 없으면 팀 약속으로 지킵니다.
- approve 후 새 커밋이 push되면 approve가 초기화될 수 있습니다.

## 머지

**Squash and merge만 사용합니다.** 저장소 설정에서 merge commit과
rebase merge를 비활성화하는 것을 목표로 합니다. **[확인 필요]**

1. "Squash and merge" 클릭
2. 머지 커밋 제목을 `<type>: <설명> (#PR번호)` 형식으로 확인
3. Confirm

**결과:**
- 커밋이 하나로 squash됩니다.
- `Closes #이슈번호`로 연결된 이슈가 자동 close됩니다.
- 저장소 설정의 `Automatically delete head branches`를 켜 두면 브랜치가 자동 삭제됩니다.

## GitHub Projects [미정]

Project 보드는 아직 만들지 않았습니다. 사용하기로 하면 이 절을 갱신합니다.

## Labels

필요한 label은 레포에 직접 만들어 사용합니다. 후보: `feature`, `bug`,
`experiment`, `documentation`, `chore`, `question`. Issue Form이 자동으로
label을 붙이려면 레포에 같은 이름의 label이 있어야 합니다.

## CI

- `.github/workflows/branch-name-policy.yml` — 브랜치 이름이 규칙에 맞는지
  검사합니다.
- `.github/workflows/claude.yml` — Claude Code PR 리뷰
  (`CLAUDE_CODE_OAUTH_TOKEN` secret 필요, 등록 전에는 실패로 표시될 수 있음).
- **[계획]** 클라우드 연동 후 Terraform plan 같은 검증 workflow를 추가합니다.

## Special Cases

### main과 충돌

```bash
git fetch origin main
git rebase origin/main
git push --force-with-lease origin feat/12-...
```

리뷰어의 재리뷰가 필요합니다.

### 리뷰에서 수정 요청

1. 새 커밋으로 수정합니다 (amend 금지).
2. push 후 재리뷰를 요청합니다.

### PR 분리

새 이슈를 만들고 커밋을 새 브랜치로 cherry-pick한 뒤 별도 PR을
생성합니다. 양쪽 PR 본문에 서로 링크를 남깁니다.

## Troubleshooting

- **PR이 merge되지 않을 때:** Draft 상태, approve 2명 충족, 대화
  resolve, 충돌, required check 실패 여부를 확인합니다.
- **Claude 리뷰가 실행되지 않을 때:** `CLAUDE_CODE_OAUTH_TOKEN` secret,
  Draft 여부, workflow event(`opened`, `ready_for_review`), Actions
  권한을 확인합니다.
- **(클라우드 연동 후) GCP 인증 workflow가 실패할 때:** OIDC provider와 service account
  binding, `permissions`의 `id-token: write`, 대상 project id와 service
  account email, 최소 권한 IAM role을 확인합니다.
- **이슈가 자동으로 닫히지 않을 때:** PR 본문의 `Closes #이슈번호`,
  `main`으로의 merge 여부, 이슈 번호가 같은 저장소의 번호인지
  확인합니다.
