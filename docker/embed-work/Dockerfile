# 기사 임베딩 작업 이미지 (이슈 #73).
# Airflow가 KubernetesPodOperator로 이 이미지의 Pod를 띄워 embed_articles DAG를 실행한다.
#   embed_articles → python /app/ingest/embed_articles.py
# 모델(intfloat/multilingual-e5-base, 약 1.1GB)을 빌드 때 미리 받아 이미지에 넣는다.
# Pod는 HF_HUB_OFFLINE=1로 돌아서 실행 중에 인터넷에서 모델을 받지 않는다.
# 빌드 컨텍스트는 data-ml-pipeline 저장소 루트다. 방법은 docker/ml-work.md.
FROM python:3.12-slim-bookworm

COPY --from=ghcr.io/astral-sh/uv:0.8.4 /uv /usr/local/bin/uv

ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH=/opt/venv/bin:$PATH \
    HF_HOME=/opt/hf

WORKDIR /app

# embed 묶음(sentence-transformers, CPU 전용 torch 등). torch는 pyproject.toml 설정대로 CPU 전용 저장소에서 받는다.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --extra embed && rm -rf /root/.cache/uv

# 모델을 이미지 안 HF_HOME에 내려받는다. 리비전은 Airflow Variable embed_model_revision과 맞춘다(기본 main).
ARG EMBED_MODEL=intfloat/multilingual-e5-base
ARG EMBED_MODEL_REVISION=main
RUN python -c "from sentence_transformers import SentenceTransformer as S; S('${EMBED_MODEL}', revision='${EMBED_MODEL_REVISION}')"

# DAG가 실행하는 코드. ingest/embed_articles.py는 data-ml-pipeline PR #37이 main에 머지된 뒤에 생긴다.
COPY ingest/ /app/ingest/
