# Feast·데이터 적재 작업 이미지 (이슈 #73, 이슈 #56).
# Airflow가 KubernetesPodOperator로 이 이미지의 Pod를 띄워 아래 DAG를 실행한다.
#   feast_materialize   → python /app/features/feast/materialize.py
#   load_raw            → python /app/ingest/load_raw.py
#   clean_events        → python /app/transform/clean_events.py
#   build_feast_sources → python /app/transform/build_feast_sources.py
# Airflow 이미지와 라이브러리 버전이 충돌해서(feast가 google-cloud-storage<3 요구) 따로 만든다.
# 빌드 컨텍스트는 data-ml-pipeline 저장소 루트다. 방법은 docker/ml-work.md.
FROM python:3.12-slim-bookworm

COPY --from=ghcr.io/astral-sh/uv:0.8.4 /uv /usr/local/bin/uv

# 가상환경을 /opt/venv에 만들고 PATH 앞에 둔다. 그래서 DAG의 "python"이 이 환경을 쓴다.
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH=/opt/venv/bin:$PATH

WORKDIR /app

# uv.lock 그대로 설치한다(--frozen: lock과 다르면 실패). 패키지 목록은 pyproject.toml의 airflow-dag 묶음.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --extra airflow-dag && rm -rf /root/.cache/uv

# DAG가 실행하는 코드. ingest/·transform/은 data-ml-pipeline PR #33·#35·#39가 main에 머지된 뒤에 생긴다.
COPY features/ /app/features/
COPY ingest/ /app/ingest/
COPY transform/ /app/transform/
