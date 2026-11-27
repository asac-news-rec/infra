# Airflow (Helm)

이슈 #35. Airflow 공식 Helm 차트를 `airflow` 네임스페이스에 설치합니다. DAG는 GitHub 저장소 `data-ml-pipeline`의 `dags/` 폴더에서 git sync로 가져옵니다(멘토 11/12, 11/15). 조직 정책으로 deploy key를 쓸 수 없어 읽기 전용 개인 토큰(fine-grained PAT)으로 읽습니다.

## 구성 요약
- 차트 `apache-airflow/airflow` 1.22.0, Airflow 3.2.2
- 실행 방식 `LocalExecutor`, 작업 코드는 KubernetesPodOperator로 별도 파드에서 실행
- 이미지는 모두 우리 Artifact Registry 주소(`dockerhub-mirror`, `news-rec`)를 씁니다. `git-sync`는 `registry.k8s.io`에서 `news-rec`로 복사한 것입니다.
- 메타데이터 DB는 차트에 들어 있는 PostgreSQL(디스크 사용). 나중에 Cloud SQL로 바꿉니다.
- 외부 접속(GitHub 등)은 Cloud NAT(이슈 #36)가 필요합니다.

## 설치 순서 (베스천 안에서)
1. 노드를 켭니다(고정 노드 2개 권장). 메모리와 CPU가 모자라면 파드가 `Pending`으로 남습니다.
2. 읽기 전용 토큰을 만듭니다. 조직 정책으로 deploy key를 쓸 수 없습니다(2026-11-16 확인). GitHub → Settings → Developer settings → Fine-grained tokens → Generate new token.
   - Resource owner: `asac-news-rec`, Repository access: Only select repositories → `data-ml-pipeline`
   - Repository permissions: Contents → **Read-only** (Metadata는 자동)
   - Expiration: 2026-12-31 (최종발표 12/17 이후)
   - 조직이 승인을 요구하면 승인 요청이 가므로 승인 뒤에 사용할 수 있습니다. 토큰은 화면에 한 번만 보이니 채팅과 저장소에 올리지 않습니다.
3. 토큰이 저장소를 읽을 수 있는지 먼저 시험합니다(WSL). 토큰은 화면에 보이지 않게 입력합니다.
   ```bash
   read -rsp "토큰 붙여넣기: " T; echo
   git -c credential.helper= -c http.extraheader="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$T" | base64 -w0)" ls-remote https://github.com/asac-news-rec/data-ml-pipeline.git
   unset T
   ```
   `refs/heads/main` 같은 줄이 나오면 성공입니다. 오류(403, 404)면 토큰 권한이나 조직 승인 대기를 확인합니다.
4. 네임스페이스와 Secret을 만듭니다(베스천 안). 차트가 키 4개를 모두 참조하므로 같은 값을 4개 키로 넣습니다.
   ```bash
   kubectl create namespace airflow
   read -rsp "토큰 붙여넣기: " T; echo
   kubectl -n airflow create secret generic airflow-git-credentials --from-literal=GITSYNC_USERNAME=<GitHub-아이디> --from-literal=GITSYNC_PASSWORD="$T" --from-literal=GIT_SYNC_USERNAME=<GitHub-아이디> --from-literal=GIT_SYNC_PASSWORD="$T"
   unset T
   ```
5. 외부 접속(NAT)이 준비되었는지 확인합니다(이슈 #36).
6. 설치 전에 Secret이 생겼는지 확인합니다.
   ```bash
   kubectl -n airflow get secret airflow-git-credentials
   ```
7. 설치합니다.
   ```bash
   helm upgrade --install airflow apache-airflow/airflow --version 1.22.0 --namespace airflow -f helm/airflow/values.yaml --timeout 10m
   ```
8. 확인합니다. 파드 5개(api-server, dag-processor, postgresql, scheduler, triggerer)가 모두 `Running`이어야 합니다.
   ```bash
   kubectl -n airflow get pods
   ```

## 2026-11-16 설치 결과와 주의
- 설치 완료: 14:56 KST. 파드 5개 `Running`, 웹 화면 접속 확인(베스천 터널). git sync가 저장소를 가져오는 것을 로그로 확인했습니다.
- **권한 표(Role/RoleBinding)**: 베스천 계정에는 이를 만들 권한이 없어서 `rbac.create: false`로 설치했습니다. 설치 시 에러가 나고, 그 상태로 `helm uninstall`도 같은 이유로 실패합니다(이때는 `kubectl delete namespace airflow`로 비웁니다). 11/17에 베스천 권한을 주어(이슈 #43) `true`로 `helm upgrade`했습니다. Role 2개(`airflow-pod-launcher-role`, `airflow-pod-log-reader-role`)가 만들어지고, Airflow 서비스 계정으로 시험 파드가 만들어지는 것을 확인했습니다(13:55).
- **디스크 한도**: 서울 리전의 SSD 계열 디스크 합계 한도가 300GB(`SSD_TOTAL_GB`)입니다. 로그 디스크 기본값(스케줄러, triggerer 각 100Gi)으로는 한도를 넘어 triggerer 디스크가 만들어지지 않았습니다. 값 파일에서 5Gi로 줄였습니다. 노드 부팅 디스크(노드당 50GB), postgres 8Gi, MLflow 10Gi와 합쳐 계산합니다.
- **지울 때 디스크는 자동으로 지워지지 않습니다.** `helm uninstall` 뒤 `kubectl -n airflow delete pvc --all`을 실행해야 디스크가 해제됩니다(기록이 사라집니다).
- 기본 관리자 계정은 `admin` / `admin`입니다. 접속은 베스천 터널로만 열리지만 바꿔야 합니다(아래 "확인이 남은 것").

## 2026-11-17 변경: GCP 접근(Workload Identity, 이슈 #37)
- Terraform(`airflow-sa.tf`)이 GCP 서비스 계정 `airflow`와 Workload Identity 연결(`airflow-scheduler`, `airflow-triggerer`, `airflow-task`)을 만듭니다. `values.yaml`의 `scheduler`, `triggerer` 서비스 계정 주석이 이 연결을 씁니다.
- `airflow-task`는 KubernetesPodOperator 작업 파드 전용 서비스 계정으로, 차트가 만들지 않아 `kubectl`로 따로 만듭니다(작업에서 `service_account_name="airflow-task"`를 지정).
  ```bash
  kubectl -n airflow create serviceaccount airflow-task
  kubectl -n airflow annotate serviceaccount airflow-task iam.gke.io/gcp-service-account=airflow@<프로젝트-ID>.iam.gserviceaccount.com
  ```
- 시험(11/17 16:07): 스케줄러 파드에서 `raw-logs`의 `served/` 경로 생성·읽기·삭제 성공, 허용 밖 경로는 403.
- **`helm upgrade`할 때 베스천의 값 파일이 오래되었을 수 있습니다.** 11/17에는 베스천의 `~/airflow-values.yaml`이 실제 설치 값과 달라 `updates to statefulset spec ... forbidden`이 났습니다. 저장소의 `helm/airflow/values.yaml`을 베스천에 복사해 쓰거나, 일부만 바꿀 때는 `--reuse-values --set <키>=<값>`으로 실제 설치된 값을 재사용합니다.

## 2026-11-17 변경: 로그를 GCS에 저장(이슈 #50)
- 작업 로그는 버킷 `final-project-513508-airflow-logs`의 `logs/` 아래에 저장됩니다(Terraform `airflow-logs.tf`, 60일 뒤 자동 삭제). `values.yaml`의 `config.logging`과 `apiServer` 서비스 계정 주석이 이 설정입니다.
- 설정은 환경 변수가 아니라 `airflow.cfg`(ConfigMap)로 들어가므로 파드에서 `env | grep AIRFLOW__LOGGING`으로 확인되지 않습니다. DAG를 실행해 GCS에 로그 파일이 생기는지 봅니다: `gcloud storage ls -r gs://final-project-513508-airflow-logs/`
- 로그 디스크(5Gi)는 작업 중 임시 파일용으로 남겨 둡니다.

## 2026-11-18 변경: 로깅 내보내기 이미지와 DB 접속 정보 (이슈 #37, #52)
세호 님의 로깅 내보내기 DAG(`export_behavior_logs.py`)는 LocalExecutor라서 스케줄러 파드 안에서 돕니다. 그래서 DAG가 쓰는 코드와 DB 접속 정보가 Airflow 이미지와 환경 변수에 있어야 합니다.
- 이미지: `docker/airflow/Dockerfile`. 기본 Airflow 3.2.2에 프런트 레포의 `services/logging-server/logging_service/`를 `/opt/logging-server/logging_service`로 복사하고, `PYTHONPATH=/opt/logging-server`, `psycopg[binary]==3.3.8`, `google-cloud-storage==3.17.1`을 설치합니다. 태그에는 프런트 커밋 SHA 앞 7자리를 적습니다(`3.2.2-logging-8bacd79`).
  ```bash
  # WSL: 프런트 레포를 해당 SHA로 받아 logging_service 폴더만 빌드 폴더에 복사한 뒤 빌드·푸시
  gh repo clone asac-news-rec/frontend frontend-src && cd frontend-src && git checkout 8bacd79cef622b67aef9cc18ee9bae7bcdfce75c && cd ..
  mkdir -p context && cp -r frontend-src/services/logging-server/logging_service context/
  docker build -f ~/infra/docker/airflow/Dockerfile -t asia-northeast3-docker.pkg.dev/final-project-513508/news-rec/airflow:3.2.2-logging-8bacd79 context
  docker push asia-northeast3-docker.pkg.dev/final-project-513508/news-rec/airflow:3.2.2-logging-8bacd79
  ```
- DB 접속 문자열 Secret(`logging-airflow-database-url`, 키 `LOGGING_DATABASE_URL`): 비밀번호가 화면과 베스천에 남지 않게, WSL에서 만들어 ssh 입력으로 흘려 보냅니다.
  ```bash
  printf 'postgresql://logging_airflow:%s@cloud-sql-proxy.airflow.svc:5432/behavior_logs' "$(gcloud secrets versions access latest --secret=logging-airflow-db-password)" | gcloud compute ssh news-rec-bastion --zone asia-northeast3-a --tunnel-through-iap --project final-project-513508 --command 'kubectl create secret generic logging-airflow-database-url -n airflow --from-file=LOGGING_DATABASE_URL=/dev/stdin'
  ```
  비밀번호를 바꾸면 Secret을 다시 만들고(`kubectl delete secret` 후 위 명령) 스케줄러 파드를 다시 시작합니다.
- 적용: `values.yaml`의 `images.airflow`와 `secret`(차트의 `env`는 `valueFrom`을 받지 않아 `secret` 값을 씁니다). 베스천의 `~/airflow-values.yaml`이 오래되었을 수 있어 저장소의 값 파일을 복사하거나 `--reuse-values --set`을 씁니다. 11/18 11:13에는 아래로 적용했습니다(REVISION 8).
  ```bash
  helm upgrade airflow apache-airflow/airflow -n airflow --version 1.22.0 --reuse-values --set images.airflow.repository=asia-northeast3-docker.pkg.dev/final-project-513508/news-rec/airflow --set images.airflow.tag=3.2.2-logging-8bacd79 --set-json 'secret=[{"envName":"LOGGING_DATABASE_URL","secretName":"logging-airflow-database-url","secretKey":"LOGGING_DATABASE_URL"}]' --timeout 10m --wait
  ```
- 확인(11/18 11:18): 스케줄러 파드의 이미지가 `3.2.2-logging-8bacd79`이고, 스케줄러 컨테이너에서 `psycopg.connect(os.environ["LOGGING_DATABASE_URL"])`로 접속해 `('logging_airflow', 'behavior_logs')`가 나오는 것을 확인했습니다. `airflow dags list-import-errors`는 `No data found`입니다.
- 11/24 추가: 내보내기 코드(`logging_service/interval_export.py`)가 `os.environ["GCS_BUCKET"]`, `os.environ["GOOGLE_CLOUD_PROJECT"]`를 그대로 읽는데 REVISION 8까지 두 값이 없었습니다(스케줄러 컨테이너 `env`와 `helm get values`로 확인). 비밀 값이 아니라서 `values.yaml`의 `env`로 넣고 11/24 11:25(KST)에 아래로 적용했습니다(REVISION 9). 적용 전에는 `env` 칸이 비어 있어 덮어쓴 값이 없습니다.
  ```bash
  helm upgrade airflow apache-airflow/airflow -n airflow --version 1.22.0 --reuse-values --set-json 'env=[{"name":"GCS_BUCKET","value":"final-project-513508-raw-logs"},{"name":"GOOGLE_CLOUD_PROJECT","value":"final-project-513508"}]' --timeout 10m --wait
  ```
  확인: `sts/airflow-scheduler`, `deploy/airflow-dag-processor`에서 `env | grep -E "GCS_BUCKET|GOOGLE_CLOUD_PROJECT"`로 두 줄이 나옵니다. 스케줄러는 Deployment가 아니라 StatefulSet이라 `deploy/airflow-scheduler`로는 찾을 수 없습니다. 이미 `env`에 값이 있는 상태에서 `--set-json 'env=[...]'`를 쓰면 목록 전체가 바뀌므로 기존 값을 함께 넣습니다.
- 11/25 추가: 내보내기 DAG(`export_behavior_logs.py`)는 `BEHAVIOR_EXPORT_CRON`이 없으면 자동 실행하지 않고, `catchup=True`라 `BEHAVIOR_EXPORT_START`부터 밀린 구간을 채웁니다. 세호 님 요청대로 첫 내보내기는 prune 없이 스케줄러 Pod에서 `export_interval(2026-11-24T01:00Z, 2026-11-25T01:45Z)`만 직접 실행하고(job 4개, served 120·actions 13), DB·GCS 건수와 ID 대조 뒤 11/25 15:1x(KST)에 아래로 적용했습니다(REVISION 10). 백업은 베스천 `~/airflow-values-rev9.yaml`.
  ```bash
  helm upgrade airflow apache-airflow/airflow -n airflow --version 1.22.0 --reuse-values --set-json 'env=[{"name":"GCS_BUCKET","value":"final-project-513508-raw-logs"},{"name":"GOOGLE_CLOUD_PROJECT","value":"final-project-513508"},{"name":"BEHAVIOR_EXPORT_CRON","value":"*/5 * * * *"},{"name":"BEHAVIOR_EXPORT_START","value":"2026-11-25T01:45:00Z"}]' --timeout 10m
  ```
  확인: 스케줄러·dag-processor에서 `printenv`로 네 값, `airflow dags unpause export_behavior_logs` 뒤 01:45Z부터 5분 구간이 차례로 success(16:16에 07:10Z까지 따라잡음). 각 실행의 prune은 내보냈고 받은 지 24시간 지난 기록만 지웁니다. 되돌리기는 `helm rollback airflow 9 -n airflow` 후 DAG pause.
- `logging_airflow`의 테이블 권한(`airflow-grants.sql`)은 FastAPI가 `behavior_logging` 스키마를 만든 뒤 관리자 계정으로 적용합니다(프런트 레포 `services/logging-server/sql/airflow-grants.sql`).

## 접속
공개 주소가 없습니다. 베스천에서 `kubectl -n airflow port-forward`로 접속합니다. 서비스 이름과 포트는 설치 후 `kubectl -n airflow get svc`로 확인합니다(**[확인 필요]**).

## 확인이 남은 것 (설치하면서 채웁니다)
- 관리자 계정 비밀번호 변경(현재 기본값 `admin`/`admin`). 설정 방법은 차트 문서로 확인
- 정적 API 비밀 키 설정(설치 출력에 "동적으로 생성된 키라 재시작이 잦을 수 있다"는 경고)
- 파드별 자원 요청과 한도(설치 후 측정), 작업 파드를 `worker` 노드 풀에 올리기 위한 toleration
- Airflow 표시 시간대(KST)
- `helm template`에서 값 이름이 무시되지 않았는지 이미지 목록으로 확인

## 롤백
```bash
helm -n airflow uninstall airflow
```
메타데이터 DB 디스크(PVC)는 남을 수 있습니다. 완전히 지울 때만 `kubectl -n airflow delete pvc --all`을 실행합니다(기록이 사라집니다).

- 11/27 추가: 세호 님 요청으로 로깅 코드를 frontend `b84398c`(#71, 내보내기 준비 잠금 범위 개선)로 올렸습니다. SQL 파일은 바뀌지 않아 DB 작업은 없고, 새 의존성 `psycopg-pool`은 로깅 서버 연결 풀 전용이라 이미지에 넣지 않았습니다(Airflow는 `interval_export` 경로만 씀). 13:19(KST) 적용(REVISION 11), 백업은 베스천 `~/airflow-values-rev10.yaml`.

  ```bash
  helm upgrade airflow apache-airflow/airflow -n airflow --version 1.22.0 --reuse-values --set images.airflow.tag=3.2.2-logging-b84398c --timeout 10m --wait
  ```
