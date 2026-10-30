# CLAUDE.md — Global

## 기본 행동 규칙

구현 요청을 받으면 항상 아래 순서로 진행한다.

```
1. 영향도 분석 → docs/research/{YYYYMMDD}-{seq}-{task-slug}.md 에 상세 기록
                 research.md 에 인덱스 한 줄 추가
2. 구현 설계   → plan.md 에 작성 (Status: READY_FOR_IMPLEMENT)
3. "설계 완료. 구현을 진행할까요?" 출력 후 대기
4. 사용자 확인 후 구현 시작
5. 구현 완료   → finish-task 스킬 실행
```

### 구현 시작 조건 (모두 충족해야 함)
- `research.md` 에 인덱스가, `docs/research/{YYYYMMDD}-{seq}-{task-slug}.md` 에 상세 분석이 기록되어 있을 것
- `plan.md` Status 가 `READY_FOR_IMPLEMENT` 일 것
- 사용자가 구현 진행을 확인했을 것

**plan.md 기록 전에는 코드를 한 줄도 생성하지 않는다.**

### 예외
사용자가 명시적으로 "바로 구현해줘" 라고 하면 분석/설계 단계 생략 가능.

---

## research.md — 인덱스

프로젝트 루트. 상세 분석 파일에 대한 색인만 유지. 태스크마다 상단에 추가 (newest first). 삭제하지 않는다.

```markdown
## [YYYY-MM-DD] <task>
- Layers: `path/to/layer/`, `path/to/other/`
- Breaking: yes / no
- 반영: 보류 / 반영됨 / 폐기
- 상세: `docs/research/{YYYYMMDD}-{seq}-{task-slug}.md`
```

- 반영: 초기 작성 시 기본값 `보류`. "구현 완료 후 처리" 단계에서 자동으로 `반영됨`으로 전환. `폐기`는 수동으로만 기입.

## docs/research/{YYYYMMDD}-{seq}-{task-slug}.md — 상세

태스크마다 파일 1개 생성. 완료 여부와 무관하게 유지, 삭제하지 않는다.

- seq: 같은 날짜 내 순번, 2자리 (`01`, `02`, ...). `docs/research/{YYYYMMDD}-*` 파일 중 가장 큰 seq + 1. 해당 날짜 파일이 없으면 `01`.

```markdown
## [YYYY-MM-DD] <task>

### Task
<한 줄 요약>

### Layers Affected
- `path/to/layer/` — 이유

### API Impact
- Breaking: yes / no
- Changed: <엔드포인트 또는 N/A>
- Consumers: <목록 또는 N/A>

### Findings
<기존 코드 분석 내용, 패턴, 참고할 사항>

### Risks
- <리스크 또는 불확실한 부분>
```

---

## plan.md 형식

프로젝트 루트. 현재 진행 중인 태스크 1개만 유지.

```markdown
## [YYYY-MM-DD] <task>

### Task
<한 줄 요약>

### Files
| 파일 경로 | 클래스명 | 작업 |
|-----------|----------|------|
| `path/To/File.java` | `ClassName` | create / modify |

### Decision
<선택한 접근법과 이유>

### Rejected Alternatives
- <대안>: <선택하지 않은 이유>

### Verification
- 자동: <실행할 검증 — 컴파일, 테스트 등. 없으면 "없음">
- 수동: <사용자가 직접 확인해야 할 항목 — 확인 환경, 케이스>

### Status
READY_FOR_IMPLEMENT
```

- Verification: 자동으로 확인할 수 없는 부분은 수동 항목에 빠짐없이 적는다. 테스트가 없는 영역이면 그 사실을 적는다.

---

## 구현 완료 후 처리

구현이 끝나면 `finish-task` 스킬을 실행한다. 절차, 커밋 조건, Git 추천 형식(브랜치명, 커밋 메시지)은 스킬에 정의되어 있다.

- 수행 내용: plan.md Status `DONE` 처리 → research.md 반영 상태 `반영됨` → `docs/exec-plan/` 보관 → plan.md 초기화 → 커밋 메시지 작성 → 로컬 커밋
- 커밋은 사용자 요청 없이 바로 한다. 단 Files 표(보관한 exec-plan 기준)의 파일만, 자동 검증 실패·설계 이탈이 없을 때만. 조건은 스킬 참고.
- 푸시와 브랜치 생성은 사용자가 요청할 때만 한다.
- 커밋 메시지나 브랜치명만 필요한 경우에도 스킬의 "Git 추천 형식"을 따른다.

---

## 구현 단계 규칙

- `plan.md` 에 확정된 파일 목록과 설계만 구현
- 설계 이탈이 필요한 경우 구현 중단 후 사용자 확인
- 관련 없는 코드 같은 범위에서 리팩토링 금지

---

## 코드 주석 규칙

주석은 코드만 봐서는 알 수 없는 것만 남긴다. 코드와 어긋난 주석은 없는 것보다 해롭다.

- 주석 본문은 한글로 작성한다.

```java
// [WHY] 코드로 드러나지 않는 이유 — 비즈니스 규칙, 외부 시스템 제약, 우회한 버그 등
// [RISK] 테스트·assert 로 표현하기 어려운 엣지케이스 또는 취약한 가정
// [TODO] 티켓 번호 또는 해소 조건이 있을 때만 — 예: [TODO] ABC-123 결제사 v2 전환 후 제거
```

- `[RISK]` 는 먼저 테스트·assert·타입으로 표현할 수 있는지 검토하고, 불가능할 때만 주석으로 남긴다.
- API 계약 변경(Breaking)은 코드 주석이 아니라 커밋 메시지의 `BREAKING CHANGE:` 와 PR 설명에 남긴다.
- 변경 경위를 설명하는 주석 금지 — "기존 로직 대신 ~로 변경", "요청에 따라 수정" 등은 커밋 메시지에 쓴다.
- 코드가 하는 일을 다시 설명하는 주석 금지 — 이름과 구조로 드러낸다.
- 주석이 달린 코드를 수정하면 그 주석이 여전히 맞는지 확인하고 함께 고치거나 지운다.
- public 메서드에만 Javadoc
