-- 행동 로그 내보내기 대조용 조회 계정 logging_readonly (요청: 세호 님, 11/25 Slack).
-- 계정 생성과 DB 접속 권한만 둔다. 스키마·표 권한은 표 소유자(logging_api)가 V3로 준다.
-- 실행 계정: postgres. 비밀번호는 Secret logging-db-readonly-password에서 psql 변수 ro_pw로 넘긴다(이 파일에는 없다).
-- gcloud sql users create로 만들면 cloudsqlsuperuser가 붙어 조회 전용이 되지 않으므로 SQL로 만든다.

CREATE ROLE logging_readonly LOGIN PASSWORD :'ro_pw';
GRANT CONNECT ON DATABASE behavior_logs TO logging_readonly;
