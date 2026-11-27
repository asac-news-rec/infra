-- 뉴스 피드 반환 로그 테이블 (infra 이슈 #66, 요청: 백엔드).
-- 백엔드가 어떤 독자에게 어떤 기사를 몇 번째로 언제 돌려줬는지 기사 1건당 1행으로 기록한다.
-- score, model_version, features_as_of는 추론 서버 연동 전까지 NULL 허용.
-- 기사가 지워져도 반환 이력을 남기려고 article_id에 외래 키를 걸지 않는다.
--
-- Flyway 버전 파일 형식(V<버전>__<설명>.sql)으로 둔다. 지금은 Flyway 도입 전이라(#61)
-- 사람이 psql로 한 번 적용했다. 트랜잭션은 psql -1 옵션으로 묶는다(Flyway도 파일 단위로 묶어 실행한다).

CREATE TABLE IF NOT EXISTS public.news_impressions (
    impression_id  UUID PRIMARY KEY,
    request_id     UUID NOT NULL,
    reader_id      TEXT NOT NULL,
    article_id     TEXT NOT NULL,
    position       INTEGER NOT NULL CHECK (position > 0),
    served_at      TIMESTAMPTZ NOT NULL,
    score          DOUBLE PRECISION,
    model_version  TEXT,
    features_as_of TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS news_impressions_request_id_idx
    ON public.news_impressions (request_id);

CREATE INDEX IF NOT EXISTS news_impressions_served_at_idx
    ON public.news_impressions (served_at);

-- 백엔드 FastAPI의 DB 계정(Cloud Run news-feed의 PGUSER)에는 쓰기(INSERT)만 준다.
GRANT INSERT ON public.news_impressions TO news_app;
