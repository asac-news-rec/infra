-- Airflow 행동 로그 내보내기(logging_airflow 계정) 권한 (infra 이슈 #58, 요청: 세호 님).
-- 원본: frontend 커밋 8bacd79 services/logging-server/sql/airflow-grants.sql
--   psql 변수(:"logging_database", :"airflow_role")를 실제 값(behavior_logs, logging_airflow)으로 바꾸고,
--   트랜잭션은 psql -1 옵션으로 묶으므로 BEGIN/COMMIT은 뺐다. 권한 내용은 원본과 같다.
-- 실행 계정: logging_api(스키마·테이블 소유자). Cloud SQL의 postgres는 슈퍼유저가 아니어서
--   남의 테이블에 GRANT하면 오류가 아니라 경고("no privileges were granted")만 남고 적용되지 않는다.
-- Flyway 도입(#61) 전이라 사람이 적용했다. 로깅 DB 스키마 자체는 로깅 API가 만든다(schema_version 테이블).

GRANT CONNECT ON DATABASE behavior_logs TO logging_airflow;
GRANT USAGE ON SCHEMA behavior_logging TO logging_airflow;

-- API가 철회 사용자와 삭제 대상을 기록하고, Airflow는 남은 GCS 객체를 지우려고 읽기만 한다.
GRANT SELECT ON behavior_logging.schema_version,
    behavior_logging.revoked_users, behavior_logging.deletion_targets
    TO logging_airflow;
GRANT SELECT, DELETE ON behavior_logging.served_records,
    behavior_logging.action_records TO logging_airflow;
GRANT SELECT, INSERT, DELETE ON behavior_logging.export_members TO logging_airflow;
GRANT SELECT, INSERT ON behavior_logging.export_jobs TO logging_airflow;
GRANT UPDATE (status, attempts, last_error, next_attempt_at, storage_receipt, content)
    ON behavior_logging.export_jobs TO logging_airflow;
