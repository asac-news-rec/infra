# 에이전트 Terraform 참조

> Last Updated: 2026-11-03

> **[계획] 이 저장소에는 아직 Terraform 코드가 없습니다.** GCP 계정이 발급된 뒤
> `terraform/`을 만들면서 이 문서의 경로와 명령을 실제 값으로 갱신합니다.
> 아래는 그때 따를 **원칙**이며, 이미 있는 파일처럼 다루지 않습니다.

Terraform 코드 스타일, 파일 구성, 검증 규칙을 다루는 문서입니다.

## 이 문서를 볼 때

- (계정 발급 후) Terraform 리소스를 추가하거나 수정할 때
- 변수, locals, outputs 배치를 정해야 할 때
- 검증 명령과 plan 실행 기준이 필요할 때

## 파일 구성 [계획]

`terraform/envs/dev/`는 리소스 종류별 파일 분리 패턴을 따릅니다:

- `versions.tf` — required_version, required_providers, provider 블록.
  provider 설정(project/region)은 여기에만 둡니다.
- `variables.tf` — 모든 입력 변수. `description`을 반드시 작성합니다.
- `locals.tf` — 이름 prefix, 공통 label 등 파생 값
- `outputs.tf` — 다른 시스템이 소비하는 출력
- `<리소스종류>.tf` — `gke.tf`, `storage.tf`, `bigquery.tf`, `cloud_sql.tf`처럼
  종류별로 분리합니다.
- 재사용 묶음은 `terraform/modules/`에 둡니다.

새 리소스 종류는 새 파일로 만들고, 기존 파일에는 같은 종류의 리소스만
추가합니다.

## 이름과 스타일

- 리소스 이름은 목적이 드러나게 짓고, 클라우드 리소스 이름에는 환경 prefix를
  포함합니다. prefix 규칙은 정해지면 이 문서에 기록합니다. **[미정]**
- 하드코딩 대신 `var.`/`local.`을 사용합니다. **project id, region, 버킷 이름은
  반드시 변수로 받습니다.** 계정 교체 때 이 값들만 바꿔 같은 코드를 다시 적용하기
  위해서입니다.
- 새 변수는 `variables.tf`와 `terraform.tfvars.example`에 함께 추가합니다.
  실값 `terraform.tfvars`는 커밋하지 않습니다.
- `fmt`가 스타일의 최종 기준입니다.

## Dev Environment Defaults

- dev 리소스는 최소 비용 기준으로 시작합니다 (예: 작은 DB 인스턴스, GKE 최소 노드).
- dev에서는 `deletion_protection`을 낮게 유지하되, PR에 명시합니다.
- 운영 전환 시 바꿔야 할 항목은 주석이나 문서에 남깁니다.
- 네트워크는 private을 우선하되, 비용과 복잡도(예: NAT) 때문에 학습용 환경에
  과한 경우는 PR에서 근거를 적고 결정합니다. **[검토 필요]**
- 클라우드 API 활성화 방식(코드로 `google_project_service`를 쓸지, 수동으로 켤지)은
  팀이 정하지 않았습니다. Terraform을 시작할 때 정하고 이 문서에 기록합니다. **[미정]**

## Verification [계획]

Terraform 변경 전 필수:

```bash
terraform -chdir=terraform/envs/dev fmt -check -recursive
terraform -chdir=terraform/envs/dev init -backend=false
terraform -chdir=terraform/envs/dev validate
```

리소스 변경 PR은 추가로 `plan`을 실행합니다.

- `plan`은 실제 클라우드 project id와 인증이 준비된 뒤 실행하고, 결과 요약
  (추가/변경/삭제 리소스 수와 핵심 diff)을 PR 본문에 적습니다.
- `plan`에서 의도하지 않은 destroy/replace가 보이면 머지 전에 원인을
  해결합니다.
- `apply`/`destroy`는 사용자가 명확히 요청했을 때만 실행합니다.

## State & Secrets

- Terraform state(`*.tfstate`), plan 파일, `.terraform/`은 커밋하지 않습니다.
  (저장소에 `.gitignore`가 준비되어 있어야 합니다. **[계획]**)
- 비밀번호 등 민감값은 `random_password` + Secret Manager 패턴을 사용하고,
  output으로 노출하지 않습니다 (필요 시 `sensitive = true`).
- state는 원격 backend(GCS 버킷)에 둘 계획입니다. 버킷 이름과 prefix는
  정해지면 기록합니다. **[미정]**
- Terraform state를 다루는 작업(mv, rm, import)은 사용자 확인 후 진행합니다.

## Structure vs Behavior Changes

- 리팩터링(파일 이동, 이름 변경)과 리소스 변경을 한 커밋에 섞지 않습니다.
- 리소스 이름 변경은 replace를 유발할 수 있으므로 `moved` 블록이나
  `terraform state mv`를 검토하고 PR에 명시합니다.
