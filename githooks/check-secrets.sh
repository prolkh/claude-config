#!/bin/bash
# 커밋·푸시 전 민감정보 검사. 걸리면 위치와 규칙을 출력하고 1 로 끝난다.
#   --staged          커밋에 들어갈 변경(git add 한 것)
#   --range <rev...>  git log 에 넘길 범위 (예: abc123 --not --remotes)
# 예외가 꼭 필요한 줄은 줄 끝에 "secret-check: allow" 를 붙인다.
# git 전역 훅(core.hooksPath = ~/.claude/githooks)으로 모든 저장소에서 실행된다.
# [WHY] 외부 도구(gitleaks 등) 없이 macOS 기본 bash 3.2 + BSD grep/awk 와 Git for Windows 의 bash 양쪽에서 동작하게 작성
set -uo pipefail

case "${1:-}" in
  --staged)
    patch() { git diff --cached -U0 --no-color --diff-filter=ACMR; }
    names() { git diff --cached --name-only --diff-filter=ACMR; }
    ;;
  --range)
    shift
    [[ $# -gt 0 ]] || { echo "사용법: $0 --range <rev...>" >&2; exit 2; }
    RANGE=("$@")
    patch() { git log -p -U0 --no-color --format='commit %h' --diff-filter=ACMR "${RANGE[@]}"; }
    names() { git log --name-only --format= --diff-filter=ACMR "${RANGE[@]}" | sort -u; }
    ;;
  *)
    echo "사용법: $0 --staged | --range <rev...>" >&2
    exit 2
    ;;
esac

# 이름(탭)정규식(탭)grep 옵션. 정규식에 | 가 들어가므로 탭으로 구분
RULES=$(cat <<'EOF'
Telegram 봇 토큰	[0-9]{8,10}:[A-Za-z0-9_-]{35}	-E
TELEGRAM_BOT_TOKEN 값	TELEGRAM_BOT_TOKEN=[^%'"[:space:]]{6,}	-E
Anthropic 키	sk-ant-[A-Za-z0-9_-]{10,}	-E
OpenAI 키	sk-(proj-)?[A-Za-z0-9_-]{20,}	-E
GitHub 토큰	(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})	-E
AWS 액세스 키	AKIA[0-9A-Z]{16}	-E
Slack 토큰	xox[baprs]-[A-Za-z0-9-]{10,}	-E
개인키	-----BEGIN [A-Z ]*PRIVATE KEY-----	-E
값을 직접 넣은 비밀값	(api[_-]?key|secret|password|passwd|token)["']?[[:space:]]*[:=][[:space:]]*["'][^"'[:space:]]{8,}["']	-iE
EOF
)

FILE_RULES=$(cat <<'EOF'
환경변수 파일(.env)	(^|/)\.env(\..*)?$
인증서·키 파일	\.(pem|key|p12)$
Telegram 허용 목록	(^|/)access\.json$
Telegram 봇 PID	(^|/)bot\.pid$
Telegram 채널 상태 폴더	(^|/)channels/telegram/
snap-bot Telegram 상태 폴더	(^|/)snap-bot/telegram/
EOF
)

# [WHY] macOS 의 mktemp -t 와 GNU(Git for Windows) 의 -t 동작이 달라 템플릿 경로를 직접 지정
TMP=$(mktemp "${TMPDIR:-/tmp}/check-secrets.XXXXXX")
trap 'rm -f "$TMP"' EXIT

# 추가된 줄만 "위치<탭>내용" 으로 펼침. 위치 = [커밋:]파일:줄
patch | awk '
  /^commit [0-9a-f]+$/ { c = $2 ":"; next }
  /^\+\+\+ /           { f = substr($0, 5); sub(/^b\//, "", f); next }
  /^@@ /               { split($0, a, " "); n = a[3]; sub(/^\+/, "", n); split(n, b, ","); ln = b[1]; next }
  /^\+/                { if (f != "/dev/null") print c f ":" ln "\t" substr($0, 2); ln++; next }
' | grep -v 'secret-check: allow' > "$TMP"

found=0
TAB=$'\t'

while IFS="$TAB" read -r name re opt; do
  [[ -n "$name" ]] || continue
  # [WHY] 위치(파일 경로)가 아닌 내용 부분에서만 찾도록 탭 뒤로 한정
  while IFS="$TAB" read -r loc text; do
    tok=$(printf '%s\n' "$text" | grep -o $opt -e "$re" | head -1)
    # [WHY] 출력에 값이 그대로 남으면 터미널 기록으로 다시 새므로 앞 4글자만
    echo "  $loc  [$name]  ${tok:0:4}…(${#tok}자)"
    found=1
  done < <(grep $opt -e "${TAB}.*${re}" "$TMP")
done <<< "$RULES"

while IFS="$TAB" read -r name re; do
  [[ -n "$name" ]] || continue
  while read -r path; do
    echo "  $path  [$name]  파일 자체를 올리면 안 됨"
    found=1
  done < <(names | grep -E -e "$re")
done <<< "$FILE_RULES"

if ((found)); then
  echo "민감정보로 보이는 내용이 있어 중단했어요. 위 위치를 고친 뒤 다시 시도하세요." >&2
  echo "예시 값처럼 꼭 필요한 줄이면 줄 끝에 'secret-check: allow' 를 붙이세요." >&2
  echo "이 저장소만 검사를 끄려면: git config core.hooksPath .git/hooks" >&2
  exit 1
fi
exit 0
