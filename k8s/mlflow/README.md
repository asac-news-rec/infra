# MLflow 서버 (임시 구성)

이슈 #30. `mlflow.yaml`을 베스천에서 `kubectl apply -f`로 올립니다. 기록(실험, 모델 버전, alias)은 디스크의 SQLite 파일에 있고 모델 파일은 GCS에 있습니다. 1차 구성이며 Cloud SQL로 옮기는 것은 후속입니다.

## 롤백
**안전한 방법 (기록 유지):** 서버만 내립니다. 디스크(PVC)와 기록은 남습니다.
```bash
kubectl -n mlflow delete deploy,svc mlflow
```
다시 올릴 때는 `kubectl apply -f mlflow.yaml`을 실행합니다.

**위험한 방법 (기록 삭제):** `kubectl delete -f mlflow.yaml`은 Namespace와 PVC까지 지웁니다. `standard-rwo`의 기본 `reclaimPolicy`가 `Delete`라서 디스크가 함께 삭제되고, 실험 기록과 alias(`champion`)가 복구되지 않습니다. 백업 없이는 실행하지 않습니다.

## 기록 보호
디스크를 지워도 남도록 PV의 회수 정책을 `Retain`으로 바꿔 둘 수 있습니다(한 번만 실행).
```bash
PV=$(kubectl -n mlflow get pvc mlflow-data -o jsonpath='{.spec.volumeName}')
kubectl patch pv "$PV" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```
백업은 서버가 기록을 쓰지 않는 시간에 파일을 복사합니다(컨테이너에 `tar`가 없으면 실패할 수 있음, 확인 필요).
```bash
POD=$(kubectl -n mlflow get pod -l app=mlflow -o jsonpath='{.items[0].metadata.name}')
kubectl -n mlflow cp "$POD":/mlflow/data/mlflow.db ./mlflow.db
```

## 계정 교체 시 바꿀 값 (3곳)
프로젝트 ID `final-project-513508`가 `mlflow.yaml`에 있습니다.
- 서비스 계정 annotation(`iam.gke.io/gcp-service-account`)
- 이미지 주소(`image:`)
- 모델 파일 경로(`--artifacts-destination`)

이미지 태그 `3.18.0`은 덮어쓸 수 있으므로 같은 태그로 재빌드하지 않고 태그를 올립니다.

## 알려진 한계 (후속 작업)
- MLflow에는 로그인이 없어 클러스터 안 파드가 접근할 수 있습니다. NetworkPolicy로 허용 구역만 열 예정입니다.
- 서비스 계정 권한이 `model-artifacts` 버킷 전체의 `objectAdmin`입니다. `objectUser`로 줄일 예정입니다.
- 기록 저장소는 SQLite입니다. Cloud SQL로 옮길 예정입니다.
