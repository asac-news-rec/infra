-- logging_readonly에 내보내기 대조에 필요한 표 4개 조회만 준다 (V2 다음).
-- 실행 계정: logging_api(스키마·표 소유자). postgres로 실행하면 경고만 남고 적용되지 않는다(V1과 같음).
-- export_jobs.content에는 내보낸 원문(독자 ID 포함)이 있다. 대조 목적이라 조회를 주되, 계속 둘지는 세호 님과 정한다.

GRANT USAGE ON SCHEMA behavior_logging TO logging_readonly;
GRANT SELECT ON behavior_logging.served_records, behavior_logging.action_records,
    behavior_logging.export_jobs, behavior_logging.export_members TO logging_readonly;
