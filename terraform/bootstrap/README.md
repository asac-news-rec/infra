# terraform/bootstrap

Terraform이 사용할 **상태 저장 버킷**과 **기본 API**를 만드는 곳입니다. **처음 한 번만** 실행합니다.

## 왜 따로 있나
Terraform 상태(지금 무엇이 만들어져 있는지 적은 장부)는 GCS 버킷에 저장합니다. 그런데 그 버킷도 먼저 만들어야 하므로, 이 단계만 **로컬 상태**로 실행합니다. 이후 `terraform/envs/dev`는 이 버킷을 상태 저장소로 사용합니다.

## 필요한 것
- Terraform 1.5 이상, gcloud CLI
- `final-project` 프로젝트에서 Owner 또는 충분한 권한이 있는 구글 계정

## 실행 순서
1. 로그인과 프로젝트 지정 (처음 한 번)

```bash
gcloud auth login
```

```bash
gcloud auth application-default login
```

```bash
gcloud config set project <프로젝트-ID>
```

```bash
gcloud auth application-default set-quota-project <프로젝트-ID>
```

2. 변수 파일 만들기 (진짜 값 파일은 Git에 올라가지 않음)

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`를 열어 `project_id`에 실제 프로젝트 ID를 적습니다.

3. 점검 → 초기화 → 미리 보기 → 생성

```bash
terraform fmt -check
terraform init
terraform validate
terraform plan -out=tfplan
```

`plan` 결과에서 **만들어지는 것(+)만** 있는지 확인합니다. 지워지는 것(-)이나 교체(-/+)가 있으면 멈춥니다. 만들어지는 것은 API 5개와 버킷 1개입니다.

```bash
terraform apply tfplan
```

4. 끝난 뒤
- `terraform output tfstate_bucket`으로 버킷 이름을 확인합니다.
- `terraform init`이 만든 `.terraform.lock.hcl`은 provider 버전을 고정하므로 **커밋합니다.**
- `terraform.tfstate`와 `terraform.tfvars`는 커밋하지 않습니다(`.gitignore`). `terraform.tfstate`는 잃어버리지 않게 따로 보관합니다.

## 문제가 생기면
| 증상 | 확인 |
|---|---|
| API가 꺼져 있다는 오류(serviceusage 등) | `gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com` 실행 후 다시 시도 |
| 403 권한 오류 | IAM에서 내 역할이 Owner인지 확인, `gcloud auth application-default login`을 다시 실행 |
| 버킷 이름이 이미 있다는 오류 | 버킷 이름은 전 세계에서 유일해야 함. `variables.tf`가 아니라 프로젝트 ID를 확인 |

## 비용
버킷 1개(상태 파일 몇 KB)와 API 활성화뿐이라 비용은 사실상 없습니다.
