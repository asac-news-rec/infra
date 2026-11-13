# MLflow 서버 이미지.
# 비공개 GKE 노드는 인터넷에서 이미지를 받을 수 없어, 이 이미지를 만들어 우리 이미지 저장소(news-rec)에 올려서 쓴다.
# 빌드는 인터넷이 되는 내 컴퓨터에서 한다. (Docker Hub의 python 이미지를 받아 mlflow를 설치)
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# mlflow: 서버 본체. google-cloud-storage: gs:// 경로에 모델 파일을 쓰기 위한 라이브러리.
# 버전은 학습 코드(클라이언트)의 mlflow와 같게 맞춘다(3.18.0).
# google-cloud-storage 3.17.1은 11/13 빌드 후 `pip freeze`로 확인한 버전이다.
RUN pip install "mlflow==3.18.0" "google-cloud-storage==3.17.1"

# root가 아닌 계정으로 실행한다. /mlflow/data는 디스크(PVC)가 붙는 위치다.
RUN useradd --create-home --uid 1000 mlflow \
    && mkdir -p /mlflow/data \
    && chown -R mlflow:mlflow /mlflow
USER 1000
WORKDIR /mlflow

EXPOSE 5000

# 실제 실행 옵션은 k8s/mlflow/mlflow.yaml의 args에서 정한다.
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
