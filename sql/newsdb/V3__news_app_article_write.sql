-- 이슈 #66 후속: 뉴스 생성기가 news_articles에 기사를 저장할 수 있게 한다.
-- 생성기 Pod(data-ml-pipeline dags/pod_templates/news-generator.yaml)는 PGUSER=news_app으로 접속하고,
-- backend generate/generate.py의 upsert_articles가 INSERT ... ON CONFLICT (id) DO UPDATE를 쓴다.
-- 11/24 확인: news_app은 news_articles에 SELECT만 있었다(INSERT·UPDATE 없음 → 생성기 저장 실패 예상).
-- id는 text이고 기본값(시퀀스)이 없어서 시퀀스 권한은 필요 없다. ON CONFLICT DO UPDATE에 필요한 SELECT는 이미 있다.
-- 피드 앱(news-feed)도 같은 news_app 계정이라 기사 수정이 가능해진다. 생성기 전용 계정 분리는 후속(#61 Flyway 때).
-- 실행: postgres 계정(테이블 소유자).

GRANT INSERT, UPDATE ON public.news_articles TO news_app;
