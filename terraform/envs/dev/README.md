# terraform/envs/dev

팀이 쓸 **기본 리소스**(원본 로그·모델 버킷, 도커 이미지 창고, 서비스 계정)를 만드는 곳입니다. 환경은 `dev` 하나만 씁니다.

## 만들어지는 것 (예상 13개, `plan`에서 확인)
| 파일 | 리소스 |
|---|---|
| `apis.tf` | API 6개 켜기 (artifactregistry, run, secretmanager, bigquery, logging, monitoring) |
| `storage.tf` | 원본 로그 버킷 `<project>-raw-logs`, 모델 파일 버킷 `<project>-model-artifacts` |
| `registry.tf` | 도커 이미지 창고 `news-rec` (태그 없는 이미지는 7일 뒤 삭제) |
| `iam.tf` | 서비스 계정 `logging-server`, `github-actions`와 최소 권한 |
| `news-generator.tf` | 뉴스 생성기용 Secret `openrouter-api-key`, `airflow` 계정의 Secret 읽기 2개, 썸네일 버킷 `images/` 한정 create·get (이슈 #59) |

만들지 않는 것: GKE, Cloud SQL, 배스천(다음 PR), 기사 이미지 버킷(태원 님과 협의 후), Cloud Run 배포 권한과 GitHub 인증(후속 PR).

## 실행 순서
`terraform/bootstrap`을 먼저 실행해 상태 버킷이 있어야 합니다. 로그인(`gcloud auth application-default login`)은 이미 되어 있어야 합니다.

1. 변수 파일 만들기

```bash
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`의 `project_id`를 실제 프로젝트 ID로 바꿉니다.

2. 초기화. 상태 버킷 이름은 코드에 쓰지 않고 여기서 넘깁니다.

```bash
terraform init -backend-config="bucket=<프로젝트-ID>-tfstate"
```

3. 점검 → 미리 보기

```bash
terraform fmt -check
terraform validate
terraform plan -out=tfplan
```

`plan`에서 **만들어지는 것(+)만** 있는지 확인합니다. 삭제(-)나 교체(-/+)가 있으면 멈춥니다.

4. 생성

```bash
terraform apply tfplan
```

## 끝난 뒤
- `terraform output`으로 버킷 이름, 이미지 주소, 서비스 계정을 확인합니다.
- `.terraform.lock.hcl`은 커밋합니다. `terraform.tfvars`, `tfplan`, `.terraform/`은 커밋하지 않습니다.

## 설계 메모
- 로깅 서버 서비스 계정은 원본 로그 버킷에 **파일 만들기만** 가능합니다(읽기·삭제 불가).
- GitHub Actions 서비스 계정은 이미지 창고에 **이미지 올리기만** 가능합니다. Cloud Run 배포 권한은 GitHub 인증(Workload Identity Federation)과 함께 후속 PR에서 추가합니다.
- 두 버킷은 `prevent_destroy`와 `force_destroy = false`로 실수로 지워지는 것을 막습니다.
- 로깅 서버의 저장 방식(세호 님과 조율 중)이 바뀌면 원본 로그 버킷과 권한이 달라질 수 있습니다(plan/adr ADR-003).

## 비용
버킷과 서비스 계정, API 활성화, 빈 이미지 창고는 사실상 비용이 없습니다. 파일이 쌓이면 저장 비용이 늘어납니다.
