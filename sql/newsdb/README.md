# newsdb 스키마 변경 기록

Cloud SQL `news-rec-pg`의 데이터베이스 `newsdb`(백엔드 뉴스 DB)에 사람이 적용한 SQL을 모아 둡니다.
파일 이름은 Flyway 버전 형식(`V<버전>__<설명>.sql`)입니다. Flyway 도입(이슈 #61) 때 이 파일들을 그대로 옮기고,
이미 적용된 버전은 baseline으로 처리합니다.

| 버전 | 내용 | 이슈 | 적용 |
| --- | --- | --- | --- |
| V1 | `news_impressions` 테이블, 인덱스 2개, `news_app`에 INSERT | #66 | 2026-11-23 11:21 KST, 장주현 (postgres 계정, psql -1) |
| V2 | 조회 전용 계정 `news_readonly`(newsdb 전체 SELECT, 이후 테이블 포함). 비밀번호는 Secret `news-db-readonly-password` | #66 | 2026-11-24 15:05 KST, 장주현 (postgres 계정, psql -1) |

## 적용 방법 (WSL)

1. 터미널 A: `cloud-sql-proxy final-project-513508:asia-northeast3:news-rec-pg --port 5433` (켜 둔 채로 둔다)
2. 터미널 B(저장소 루트): 관리자 계정으로 파일을 한 트랜잭션으로 실행한다.
   `psql "host=127.0.0.1 port=5433 dbname=newsdb user=postgres" -v ON_ERROR_STOP=1 -1 -f sql/newsdb/V1__news_impressions.sql`
3. 비밀번호는 Secret Manager에서 읽어 환경 변수로만 넘기고 화면과 파일에 남기지 않는다.

V2 적용: 비밀번호를 psql 변수로 넘긴다(파일에 비밀번호 없음).
`psql "host=127.0.0.1 port=5433 dbname=newsdb user=postgres" -v ON_ERROR_STOP=1 -v readonly_pw="$(gcloud secrets versions access latest --secret=news-db-readonly-password)" -1 -f sql/newsdb/V2__news_readonly_role.sql`

## 되돌리기

V1: 데이터가 쌓이기 전이면 `DROP TABLE public.news_impressions;` (인덱스와 권한도 함께 사라진다). 데이터가 있으면 백엔드 담당과 먼저 협의한다.

V2: `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE SELECT ON TABLES FROM news_readonly; REVOKE ALL ON ALL TABLES IN SCHEMA public FROM news_readonly; REVOKE USAGE ON SCHEMA public FROM news_readonly; REVOKE CONNECT ON DATABASE newsdb FROM news_readonly; DROP ROLE news_readonly;` 후 Secret `news-db-readonly-password` 삭제.
