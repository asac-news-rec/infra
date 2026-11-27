# 모델 학습 작업 이미지 (이슈 #79).
# Airflow가 KubernetesPodOperator로 이 이미지의 Pod를 worker(Spot) 노드에 띄워 train_pctr DAG를 실행한다.
#   train_pctr → python /app/training/build_training_set.py && python /app/training/train_lgbm.py
# 학습 코드는 추론 서버와 같은 입력 행렬(serving/matrix.py)을 쓰고, Feast 정의(features/)와
# Feast 원천 표 규칙(transform/)도 읽으므로 네 폴더를 함께 넣는다.
# 빌드 컨텍스트는 data-ml-pipeline 저장소 루트다. 방법은 docker/ml-work.md.
FROM python:3.12-slim-bookworm

# LightGBM이 쓰는 OpenMP 런타임(slim 이미지에는 없다)
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.8.4 /uv /usr/local/bin/uv

# 가상환경을 /opt/venv에 만들고 PATH 앞에 둔다. 그래서 DAG의 "python"이 이 환경을 쓴다.
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1 \
    PATH=/opt/venv/bin:$PATH

WORKDIR /app

# uv.lock 그대로 설치한다(--frozen: lock과 다르면 실패). 패키지 목록은 pyproject.toml의 train 묶음
# (feast[gcp,redis], lightgbm, scikit-learn, mlflow, pandas, pyarrow, numpy).
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --extra train && rm -rf /root/.cache/uv

# DAG가 실행하는 코드. training/은 data-ml-pipeline PR #53(#22 포함)이 main에 머지된 뒤에 생긴다.
COPY features/ /app/features/
COPY transform/ /app/transform/
COPY serving/ /app/serving/
COPY training/ /app/training/
