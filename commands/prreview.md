---
allowed-tools: Bash(git:*), Bash(curl:*), Bash(jq:*), Read(*.md)
description: "인수로 지정한 PR을 리뷰합니다."
---

가장 먼저 BITBUCKET_USER, BITBUCKET_APP_PASSWORD 환경변수가 설정되어 있는지 확인하세요.
설정되어 있지 않으면 즉시 중단하고 안내하세요.
Fetch 툴 사용 금지. Bitbucket 접근은 반드시 curl + 환경변수 인증으로만 할 것.

$ARGUMENTS를 리뷰해 주세요.
PR URL이 지정되지 않은 경우 현재 repository의 remote 정보와 current branch를 바탕으로 PR을 특정해 주세요.
또는 지정된 PR의 브랜치와 현재 브랜치가 일치하지 않는 경우 해당 브랜치로 checkout해 주세요.
만약 commit이나 파일 diff가 존재하면 중단해 주세요.

▼구체적인 절차

1. PR 내용과 현재 시점의 코멘트를 Bitbucket API로 가져와, 그 정보를 참고해 전체 개요를 설명한다.
・ 설명 내용: 어떤 배경이나 과제가 있어서 이렇게 변경했는지
2. 아래 항목에 대해 각 파일의 요약문을 표시한다.
・ before/after 수정 diff 해설
・ PR 목적에 비추어 적절한 수정인지 여부
3. 아래 항목에 대해 코드베이스를 확인한다.
・ 코드 스타일이 다른 파일과 동일한지
・ 리뷰 대상 파일에 의존하는 파일에서 변경 때문에 문제가 발생하지 않는지
4. 위 결과를 바탕으로 최종 리뷰 결과와 지적 사항을 표시한다.
5. 지적 사항에 대해 리뷰어가 구현자에게 보낼 코멘트 문장을 아래 조건에 따라 작성한다. (실제 전송 금지)
・ 구현자에 대한 존중을 잊지 않되, 문장은 짧고 간결하게 전달한다. 최대 3줄 정도
・ 코멘트 시작에는 라벨을 붙인다. 예: [must], [want], [imo], [ask], [nits], [info]
・ 파일 단위 코멘트를 우선하고, 코멘트를 표시할 위치를 명시한다.
・ 아래와 같은 경우가 발견되면 코멘트를 표시한다.
    ・ PR 목적에 부합하지 않는 구현
    ・ 보안 문제 발생
    ・ 코드 스멜 존재
    ・ 예상치 못한 부작용이나 기존 기능 파괴
    ・ API/DB를 불필요하게 호출, 처리 시간 증가, 메모리 누수 유발 요인 포함
・ 아래 케이스별로 섹션을 나눠 코멘트를 출력한다.
    ・ 수정 또는 확인이 필요한 부분
    ・ 수정은 필요 없지만 우려되는 부분
・ 테스트 추가 필요 여부는 코드베이스를 참고해 판단한다.

▼구체적인 명령어

아래 명령은 bash 문법입니다. Windows 에서도 Claude Code 의 Bash 도구는 Git Bash 로 실행되므로 그대로 사용합니다.

Bitbucket API 인증은 환경변수를 사용합니다.
- BITBUCKET_USER: $BITBUCKET_USER
- BITBUCKET_APP_PASSWORD: $BITBUCKET_APP_PASSWORD

remote URL에서 workspace와 repository slug를 추출합니다.
예: https://bitbucket.org/{workspace}/{repo_slug}

```
git remote get-url origin
```

・ PR 목록 조회 (현재 브랜치 기준):

먼저 현재 브랜치명을 확인하고, 그 값을 {branch} 에 넣어 조회합니다.

```
git branch --show-current
```

```
curl -s -G -u "$BITBUCKET_USER:$BITBUCKET_APP_PASSWORD" --data-urlencode 'q=source.branch.name = "{branch}" AND state = "OPEN"' "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/pullrequests" | jq '.values[0] | {id: .id, title: .title, description: .description, source_branch: .source.branch.name, dest_branch: .destination.branch.name, url: .links.html.href}'
```

・ PR 메타 정보:

```
curl -s -u "$BITBUCKET_USER:$BITBUCKET_APP_PASSWORD" "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/pullrequests/{pr_id}" | jq '{title: .title, description: .description, source_branch: .source.branch.name, dest_branch: .destination.branch.name, url: .links.html.href}'
```

・ PR 변경 파일 목록:

```
curl -s -u "$BITBUCKET_USER:$BITBUCKET_APP_PASSWORD" "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/pullrequests/{pr_id}/diffstat" | jq '.values[] | {status: .status, path: (.new.path // .old.path)}'
```

・ PR 파일 diff:

```
curl -s -L -u "$BITBUCKET_USER:$BITBUCKET_APP_PASSWORD" "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/pullrequests/{pr_id}/diff"
```

・ PR 코멘트 (전체):

```
curl -s -u "$BITBUCKET_USER:$BITBUCKET_APP_PASSWORD" "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/pullrequests/{pr_id}/comments" | jq '.values[] | {comment: .content.raw, file: (.inline.path // null), line: (.inline.to // null)}'
```

・ PR 브랜치 checkout:

```
git fetch origin {source_branch}
git checkout {source_branch}
```

・ 파일 특정 라인에 코멘트 작성 (실제 전송 금지 — 문장 생성만):

```
# 아래는 실제 전송 시 사용하는 명령어 형식입니다. 실행하지 말고 문장 생성 참고용으로만 활용하세요.
curl -s -u "$BITBUCKET_USER:$BITBUCKET_APP_PASSWORD" -X POST -H "Content-Type: application/json" "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo_slug}/pullrequests/{pr_id}/comments" -d '{"content": {"raw": "[imo]\n이 부분은 좀 더 안전하게 작성할 수 있을 것 같습니다."}, "inline": {"path": "src/foo/bar.js", "to": 42}}'
```

▼주의점
・ .bitbucket 폴더(Pipelines 설정 등)는 프로젝트 루트 바로 아래에 있습니다.
・ API 호출 시 author 정보(개인 식별 정보)는 가져오지 않습니다.
・ BITBUCKET_USER, BITBUCKET_APP_PASSWORD 환경변수가 설정되어 있지 않으면 실행 전에 안내해 주세요.
・ PR URL이 전달된 경우 URL에서 workspace, repo_slug, pr_id를 파싱해 사용합니다.
  예: https://bitbucket.org/{workspace}/{repo_slug}/pull-requests/{pr_id}
・ 코멘트는 정중한 말투를 사용하고, 단정적인 표현은 피합니다. 예: "~처럼 보입니다", "~일 수 있습니다", "~라고 생각합니다"