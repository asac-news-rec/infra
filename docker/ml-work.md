# 데이터 파이프라인 작업 이미지 (이슈 #73)

윤모 님 데이터 파이프라인 DAG가 쓰는 작업 이미지 2개를 만드는 방법입니다.
Airflow 이미지(`docker/airflow/Dockerfile`)와 같은 자리에 두어 이미지 관리 방식을 맞춥니다.

| 이미지 | Dockerfile | 쓰는 DAG | Airflow Variable |
| --- | --- | --- | --- |
| `news-rec/feast-work` | `docker/feast-work/Dockerfile` | feast_materialize, load_raw, clean_events, build_feast_sources | `feast_work_image` |
| `news-rec/embed-work` | `docker/embed-work/Dockerfile` | embed_articles | `embed_work_image` |

- 빌드 컨텍스트는 **data-ml-pipeline 저장소 루트**입니다(`pyproject.toml`, `uv.lock`, `features/`, `ingest/`, `transform/`).
- 태그는 data-ml-pipeline **main 커밋 SHA 앞 7자리**입니다. 같은 태그를 덮어쓰지 않습니다.
- `ingest/`, `transform/`은 data-ml-pipeline PR #33·#35·#37·#39가 main에 머지된 뒤에 생기므로 그 전에는 빌드가 실패합니다.

## 빌드와 업로드 (WSL)

```bash
# 1) data-ml-pipeline을 main 최신으로 받고 커밋 SHA를 태그로 쓴다
cd ~/data-ml-pipeline && git switch main && git pull --ff-only && SHA=$(git rev-parse --short=7 HEAD) && echo $SHA

# 2) 작업 이미지 2개 빌드(컨텍스트 = data-ml-pipeline 루트)
REG=asia-northeast3-docker.pkg.dev/final-project-513508/news-rec
docker build -f ~/infra/docker/feast-work/Dockerfile -t $REG/feast-work:$SHA ~/data-ml-pipeline
docker build -f ~/infra/docker/embed-work/Dockerfile -t $REG/embed-work:$SHA ~/data-ml-pipeline

# 3) 업로드
docker push $REG/feast-work:$SHA
docker push $REG/embed-work:$SHA
```

## Airflow에 태그 등록 (배스천)

```bash
kubectl -n airflow exec sts/airflow-scheduler -c scheduler -- airflow variables set feast_work_image asia-northeast3-docker.pkg.dev/final-project-513508/news-rec/feast-work:<SHA>
kubectl -n airflow exec sts/airflow-scheduler -c scheduler -- airflow variables set embed_work_image asia-northeast3-docker.pkg.dev/final-project-513508/news-rec/embed-work:<SHA>
```

## 롤백

Variable을 직전 태그로 되돌립니다(이미지는 지우지 않습니다).
