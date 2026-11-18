# Airflow 로깅 내보내기용 이미지. 기본 Airflow 이미지에 프런트 레포의 logging_service와 의존성을 더한다.
# LocalExecutor라서 DAG(export_behavior_logs.py)가 스케줄러 파드 안에서 돌기 때문에 코드가 이 이미지에 있어야 한다.
ARG BASE_IMAGE=asia-northeast3-docker.pkg.dev/final-project-513508/dockerhub-mirror/apache/airflow:3.2.2
FROM ${BASE_IMAGE}

# psycopg: Cloud SQL(PostgreSQL) 접속. google-cloud-storage: GCS에 내보낸 파일 저장. 버전은 프런트 팀이 검증한 값.
RUN pip install --no-cache-dir "psycopg[binary]==3.3.8" "google-cloud-storage==3.17.1"

# 프런트 레포 services/logging-server/logging_service/ 폴더를 그대로 복사한다(원본 커밋 SHA는 이미지 태그에 적는다).
# 부모 디렉터리(/opt/logging-server)를 PYTHONPATH에 넣어 `import logging_service`가 되게 한다.
COPY --chown=airflow:0 logging_service /opt/logging-server/logging_service
ENV PYTHONPATH=/opt/logging-server
