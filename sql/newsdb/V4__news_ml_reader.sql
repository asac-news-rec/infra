-- 이슈 #73: 윤모 님 embed_articles DAG가 새 기사를 읽을 때 쓰는 읽기 전용 DB 계정 news_ml_reader.
-- 기사 표(news_articles) 조회만 준다. 쓰기 계정(news_app)은 쓰지 않는다(11/19 멘토링: 목적별 계정 분리·최소 권한).
-- 반환 기록 표(news_impressions)도 ML이 쓰기로 하면 GRANT SELECT 한 줄을 추가한다(#73에서 확인 중).
-- 실행: postgres 계정으로, 비밀번호는 psql 변수 ml_reader_pw로 넘긴다(이 파일에는 비밀번호가 없다).
-- gcloud sql users create로 만들면 cloudsqlsuperuser 역할이 붙으므로 SQL로 만든다.

CREATE ROLE news_ml_reader LOGIN PASSWORD :'ml_reader_pw';

GRANT CONNECT ON DATABASE newsdb TO news_ml_reader;
GRANT USAGE ON SCHEMA public TO news_ml_reader;
GRANT SELECT ON public.news_articles TO news_ml_reader;
