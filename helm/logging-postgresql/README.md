# 행동 로그용 PostgreSQL

dev GKE에 PostgreSQL 한 개를 실행합니다. FastAPI가 로그를 커밋하고,
Airflow가 같은 DB를 읽어 GCS에 내보냅니다.

## 배포 준비

1. [GKE 접속 절차](../../terraform/envs/dev/README-platform.md)에 따라 배스천에서
   dev 클러스터 컨텍스트를 확인합니다. 배포 대상 네임스페이스는 `logging`입니다.
2. Secret Manager에 관리자와 로깅 계정의 서로 다른 비밀번호를 보관합니다.
   승인된 시크릿 전달 경로로 `logging` 네임스페이스에 Kubernetes Secret
   `logging-postgresql`을 준비합니다. 키는 `POSTGRES_PASSWORD`와
   `LOGGING_POSTGRES_PASSWORD`입니다. Chart는 기존 Secret을 참조합니다.
3. 인프라 저장소 루트에서 아래를 실행합니다. `PROJECT_ID`는 dev 프로젝트 ID입니다.

```bash
IMAGE_REPOSITORY="asia-northeast3-docker.pkg.dev/${PROJECT_ID}/dockerhub-mirror/library/postgres"
helm lint helm/logging-postgresql --set-string "imageRepository=${IMAGE_REPOSITORY}"
helm upgrade --install logging-postgresql helm/logging-postgresql \
  --namespace logging --set-string "imageRepository=${IMAGE_REPOSITORY}" \
  --wait --timeout 10m
```

빈 볼륨에서 처음 시작할 때 `logging` DB와 해당 DB를 소유하는 일반 로그인
역할 `logging`을 생성합니다. FastAPI와 Airflow의 DB 연결에는 이 계정을 쓰고
호스트는 `logging-postgresql.logging.svc.cluster.local`, 포트는 `5432`를
사용합니다. 초기화 SQL은 빈 데이터 디렉터리에서만 실행됩니다. 비밀번호를
교체할 때는 DB 역할의 비밀번호와 Secret Manager 및 사용하는 워크로드의
시크릿을 함께 갱신합니다.

## 영구 저장 검증

테스트 행을 기록하고 파드를 교체한 뒤, 같은 행이 조회되는지 검사합니다.
파드 교체 중에는 DB 연결이 잠시 끊깁니다. 신규 dev 배포에서 실행합니다.

```bash
set -e
logging_psql() {
  kubectl -n logging exec logging-postgresql-0 -- sh -ec \
    'PGPASSWORD="$LOGGING_POSTGRES_PASSWORD" psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U logging -d logging "$@"' sh "$@"
}
logging_psql -c 'CREATE TABLE logging_deploy_check (id integer PRIMARY KEY); INSERT INTO logging_deploy_check VALUES (1);'
kubectl -n logging delete pod logging-postgresql-0
kubectl -n logging rollout status statefulset/logging-postgresql --timeout=10m
test "$(logging_psql -Atc 'SELECT id FROM logging_deploy_check')" = 1
logging_psql -c 'DROP TABLE logging_deploy_check;'
```

기본 요청량은 CPU 250m와 메모리 512Mi이며, 클러스터 기본 StorageClass에서
10Gi 볼륨을 요청합니다. 필요하면 배포 전에 `storageClassName`을 지정합니다.
비용은 노드 용량과 영구 디스크에서 발생합니다. 초기 배포를 중단하려면
`kubectl -n logging scale statefulset/logging-postgresql --replicas=0`을
실행합니다. 볼륨은 유지되며 디스크 비용도 계속 발생합니다.
