---
name: finish-task
description: plan.md 로 진행한 구현이 끝난 뒤의 마무리 절차. plan.md 상태 변경, research.md 반영 처리, docs/exec-plan 보관, plan.md 초기화, 커밋 메시지 작성과 로컬 커밋까지 수행한다. 구현을 마쳤을 때, 또는 사용자가 "마무리해줘", "정리해줘"라고 할 때 사용한다.
---

# 구현 완료 후 처리

## 시작 전 확인

아래 중 하나라도 해당하면 진행하지 말고 사용자에게 알린다.
- `plan.md` 가 비어 있거나 Status 가 `READY_FOR_IMPLEMENT` 가 아님
- `plan.md` 의 Files 표에 있는 파일 중 구현되지 않은 것이 있음
- Files 표에 없는 파일을 수정했음 (설계 이탈 — 사용자 확인 후 plan.md 에 반영하고 진행)

검증(컴파일, 테스트)을 했다면 결과를, 하지 못했다면 그 사실을 마지막 보고에 그대로 적는다.

## 절차

오늘 날짜는 시스템 날짜로 구한다 (`date +%Y%m%d`, `date +%Y-%m-%d`).

1. **plan.md Status 변경** — `READY_FOR_IMPLEMENT` → `DONE — YYYY-MM-DD`
   - 구현 중 설계와 달라진 점이 있으면 Decision 에 한 줄로 남긴다.

2. **research.md 반영 상태 변경** — 해당 태스크 인덱스의 `반영: 보류` → `반영: 반영됨`
   - 태스크는 plan.md 제목(`## [YYYY-MM-DD] <task>`)으로 찾는다.
   - 다른 태스크의 인덱스는 건드리지 않는다. `폐기` 는 사용자가 직접 기입하는 값이므로 쓰지 않는다.

3. **exec-plan 보관** — `plan.md` 를 `docs/exec-plan/{YYYYMMDD}-{seq}-{task-name}.md` 로 복사
   - seq: `docs/exec-plan/{YYYYMMDD}-*` 중 가장 큰 순번 + 1, 2자리. 해당 날짜 파일이 없으면 `01`.
   - task-name: kebab-case. 같은 태스크의 `docs/research/` 파일 slug 와 맞춘다.
   - 디렉터리가 없으면 만든다. 같은 이름의 파일이 있으면 덮어쓰지 말고 순번을 올린다.

4. **plan.md 초기화** — 3의 복사본이 생긴 것을 확인한 뒤 아래 내용으로 덮어쓴다.

```markdown
# Plan

<!-- Current plan goes here -->
```

5. **커밋 메시지 작성** — 아래 "Git 추천 형식".

6. **로컬 커밋** — 아래 조건을 모두 만족하면 사용자 요청 없이 바로 커밋한다.
   - 3에서 보관한 `docs/exec-plan/` 파일의 Files 표를 기준으로 한다. `plan.md` 는 4에서 초기화되어 Files 표가 남아 있지 않다.
   - Files 표의 파일만 경로를 지정해 stage 한다 (`git add -- <파일들>`). `git add -A`, `git add .`, `git commit -a` 금지 — 사용자의 다른 미커밋 변경이 섞이지 않게 한다.
   - stage 결과(`git diff --cached --stat`)가 Files 표와 일치한다.
   - 자동 검증(컴파일·테스트 등)이 실패하지 않았다. 실패했으면 커밋하지 않고 보고한다.
   - 설계 이탈(Files 표에 없는 파일 수정)이 없다. 있으면 커밋하지 않고 사용자 확인을 받는다.
   - gitignore 여부와 관계없이 Files 표에 없는 파일(research.md·plan.md·docs/ 등)은 커밋하지 않는다.
   - 브랜치: 현재 브랜치에 커밋하고 새 브랜치는 만들지 않는다. 현재 브랜치가 기본 브랜치(main/master 등)인데 그 프로젝트에 기본 브랜치 직접 커밋을 허용한 기록(메모리·프로젝트 CLAUDE.md)이 없으면 커밋 전에 확인한다.
   - 커밋 후 `git log --oneline -1` 과 `git status --short` 로 결과를 확인한다.

푸시와 브랜치 생성은 사용자가 요청할 때만 한다. 수동 검증 항목은 커밋 후에도 마지막 보고에 남긴다.

## Git 추천 형식

```
브랜치명: <type>/<short-desc>

커밋 메시지:
<type>(<scope>): <subject>

<body>

<footer>
```

### 브랜치명
- type: `feature` / `fix` / `refactor` / `chore`
- short-desc: kebab-case, 동사-명사 형태 (예: `add-posting-permission`)

### 커밋 메시지
- type: `feat` / `fix` / `refactor` / `chore` / `docs` / `test`
- scope: 주요 변경 레이어 또는 모듈명
- subject: 한글, 50자 이내, 명사형 종결 (예: "게시 권한 검증 추가")
- body: 변경 이유(why) 위주, 문단 단위로 자유롭게 작성. 선택사항.
- footer: 해당 태스크 research 문서의 API Impact 가 `Breaking: yes` 인 경우에만 작성

```
BREAKING CHANGE: <영향받는 API/컨슈머와 변경 내용 요약>
```

### type 선택 기준
| type | 기준 |
|------|------|
| `feat` | 새 기능, 새 엔드포인트 |
| `fix` | 버그 수정 |
| `refactor` | 동작 변경 없는 코드 개선 |
| `chore` | 빌드, 설정, 의존성 |
| `docs` | 문서, 주석만 변경 |
| `test` | 테스트 코드 추가/수정만 있는 경우 |

### 출력 예시 (일반)
```
브랜치명: feature/add-posting-permission

커밋 메시지:
feat(community): 게시 권한 검증 추가

클럽 컨텍스트에서 WRITE 권한이 있는 사용자만 게시글 작성 가능하도록 제한.
기존에는 클럽 멤버십과 무관하게 인증된 사용자면 누구나 게시 가능했음.
```

### 출력 예시 (Breaking change 포함)
```
브랜치명: fix/change-post-response-schema

커밋 메시지:
fix(community): 게시글 응답 스키마 변경

목록 조회 응답에서 author 필드를 문자열에서 객체로 변경.
프론트엔드에서 작성자 상세 정보를 함께 노출해야 하는 요구사항 반영.

BREAKING CHANGE: GET /api/posts 응답의 author 필드가 string 에서
{ id, name } 객체로 변경됨. krt-fo-web, krt-bo-web 컨슈머 수정 필요.
```

## 마지막 보고

- 보관한 exec-plan 파일 경로
- research.md 에서 `반영됨` 으로 바꾼 태스크
- 검증 결과 (실행한 것 / 실행하지 못한 것)
- 커밋 해시·메시지와 커밋한 파일 (커밋하지 않았다면 그 이유와 커밋 메시지 추천)
- 남은 수동 검증 항목, push 여부
