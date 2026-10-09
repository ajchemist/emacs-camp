# 0005: 코드 변경에는 승인된 이슈가 필요하다

날짜: 2026-10-09 · 상태: 채택 · agent-camp의
[ADR 0002](https://github.com/ajchemist/agent-camp/blob/main/docs/adr/0002-approved-issue-gate.md)를 그대로 따른다

## 결정

- **승인은 이슈에 `approved` 라벨을 다는 것 하나다.** 사람이든 봇이든, 승인되지
  않은 일에는 PR이 없다. `approved`는 "할 일이다"라는 결정이고,
  `ready-for-agent`/`ready-for-human`("누가 하나")과 함께 붙을 수 있다.
- **게이트:** `triage.yml`이 `ajchemist/.github`의 재사용 workflow
  (`approved-gate.yml@v1`, `ai-coauthors.yml@v1`)를 부른다. OWNER/MEMBER/
  COLLABORATOR가 아닌 사람의 PR이 `approved` 이슈를 `Closes #n`으로 잇지 않으면
  댓글을 남기고 닫는다(문서만 바꾼 PR은 예외). 이슈에 `approved`를 달면 게이트가
  닫은 PR을 다시 연다. 새 이슈에는 승인 전에 코드를 쓰지 말라는 댓글이 붙는다.
  커밋에 AI `Co-authored-by:` 트레일러가 있는 PR은 실패한다.
- **봇:** bump PR([0004](0004-package-snapshot-pin.md))은 `approved` 티켓에서만
  열리고 `Closes #<티켓>`을 단다. `GITHUB_TOKEN`의 이벤트는 workflow를 시작하지
  않으므로 게이트가 돌지는 않지만, 같은 규칙을 지킨다.
- 소유자가 main에 직접 push하는 것은 게이트 밖이다. 게이트는 PR에만 걸린다.

## 이유

게이트 로직은 `ajchemist/.github`에 한 번만 있고, 이 저장소는 호출하는 몇 줄만
둔다. 고친 것이 모든 저장소에 함께 닿는다.
