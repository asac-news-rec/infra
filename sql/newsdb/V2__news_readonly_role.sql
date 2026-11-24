-- 이슈 #66 후속: 조회 전용 DB 계정 news_readonly.
-- 사람이 운영 데이터를 확인할 때 쓴다(앱 계정 news_app은 쓰기 권한이 있어 조회용으로 쓰지 않는다).
-- 실행: postgres 계정으로, 비밀번호는 psql 변수 readonly_pw로 넘긴다(이 파일에는 비밀번호가 없다).
-- gcloud sql users create로 만들면 cloudsqlsuperuser 역할이 붙으므로 SQL로 만든다.

CREATE ROLE news_readonly LOGIN PASSWORD :'readonly_pw';

GRANT CONNECT ON DATABASE newsdb TO news_readonly;
GRANT USAGE ON SCHEMA public TO news_readonly;

-- 지금 있는 테이블(모두 postgres 소유) 전체 조회.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO news_readonly;

-- 앞으로 postgres가 만드는 테이블도 자동으로 조회 가능.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO news_readonly;
