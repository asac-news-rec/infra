# behavior_logs 권한 변경 기록

Cloud SQL `news-rec-pg`의 데이터베이스 `behavior_logs`(로깅 DB)에 사람이 적용한 SQL입니다. 스키마 `behavior_logging`과 테이블은 로깅 API(`logging_api`)가 기동할 때 직접 만들고 `schema_version`으로 관리합니다. 여기에는 그 위에 얹는 권한만 둡니다.
파일 이름은 Flyway 버전 형식(`V<버전>__<설명>.sql`)입니다. Flyway 도입(이슈 #61) 때 옮기고, 이미 적용된 버전은 baseline으로 처리합니다.

| 버전 | 내용 | 이슈 | 적용 |
| --- | --- | --- | --- |
| V1 | `logging_airflow`에 내보내기용 권한(원본: frontend `8bacd79` `airflow-grants.sql`) | #58 | 2026-11-23 14:41 KST, 장주현 (logging_api 계정, psql -1) |

## 적용 방법 (WSL)

1. 터미널 A: `cloud-sql-proxy final-project-513508:asia-northeast3:news-rec-pg --port 5433`
2. 터미널 B(저장소 루트): **소유자 `logging_api`** 계정으로 실행한다. 비밀번호는 Secret `logging-api-db-password`에서 읽어 환경 변수로만 넘긴다.
   `psql "host=127.0.0.1 port=5433 dbname=behavior_logs user=logging_api" -v ON_ERROR_STOP=1 -1 -f sql/behavior_logs/V1__airflow_grants.sql`
3. `postgres`로 실행하면 테이블 권한이 경고만 남기고 적용되지 않는다(소유자가 아니므로). 적용 후 `has_table_privilege`로 확인한다.

## 되돌리기

`REVOKE ALL ON ALL TABLES IN SCHEMA behavior_logging FROM logging_airflow; REVOKE USAGE ON SCHEMA behavior_logging FROM logging_airflow;` (`logging_api`로 실행)
