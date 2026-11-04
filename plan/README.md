# plan/ — 설계 문서와 결정 기록

코드를 만들기 전에 "무엇을, 왜, 어떻게"를 적고, 중요한 결정은 "왜 이렇게 정했는지"를 남기는 폴더입니다. (Notion 대신 코드베이스에서 관리, 멘토 제안 11/3)

| 폴더 | 무엇을 쓰나 | 언제 쓰나 |
|---|---|---|
| `tech-spec/` | 기능·인프라를 어떻게 만들지 쓴 설계 문서 | 새 DAG, 스키마 변경, 새 인프라 등 **만들기 전** |
| `adr/` | 결정 하나를 한 장으로 기록 (상태, 컨텍스트, 결정, 근거, 결과, 대안) | 팀이나 멘토와 **무언가를 정했을 때** |

## 쓰는 규칙 (가볍게)
- 설계 문서는 **따로 PR로 올리지 않고 코드 PR에 함께** 넣습니다. PR 설명은 설계 문서 링크로 대신해도 됩니다.
- ADR은 길게 쓰지 않습니다. 한 화면에 들어가는 분량이면 충분합니다.
- 결정이 바뀌면 옛 ADR을 지우지 않고 상태를 `Superseded by ADR-xxx`로 바꾸고 새 ADR을 씁니다.
- 파일 이름: `tech-spec/0001-이름.md`, `adr/ADR-001-결정-요약.md`.
- 템플릿: `tech-spec/_template.md`, `adr/_template.md`.

## 참고
- 뱅크샐러드 테크 스펙: https://blog.banksalad.com/tech/we-work-by-tech-spec/
- ADR 작성법(CNCF 한국): https://www.cncf.co.kr/cloud-native/adr-architecture-decision-record/
