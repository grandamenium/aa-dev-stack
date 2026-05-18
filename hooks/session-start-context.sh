#!/usr/bin/env bash
# hooks/session-start-context.sh
# Injects branch, last commits, handoff/progress notes, and weekly review
# into Claude's context at session start. Capped at ~50 lines.
set -euo pipefail

HOOK_NAME="session-start-context"
source "$(dirname "$0")/_lib/aa-common.sh"
aa_hook_enabled "$HOOK_NAME" || exit 0

HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

INPUT=$(cat 2>/dev/null || echo '{}')

CWD="."
if [ "$HAS_JQ" = "1" ]; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."')
fi
cd "$CWD" 2>/dev/null || true

CTX=""

append_section() {
  local title="$1"
  local body="$2"
  [ -z "$body" ] && return 0
  CTX="${CTX}
## ${title}
${body}
"
}

# 1. Git state.
if git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "(detached)")
  LAST5=$(git log --oneline -5 2>/dev/null || true)
  DIRTY=$(git status --short 2>/dev/null | head -10 || true)
  GIT_BODY="Branch: ${BRANCH}

Recent commits:
${LAST5}"
  if [ -n "$DIRTY" ]; then
    GIT_BODY="${GIT_BODY}

Uncommitted changes:
${DIRTY}"
  fi
  append_section "Git" "$GIT_BODY"
fi

# 2. HANDOFF.md.
if [ -f HANDOFF.md ]; then
  append_section "HANDOFF.md" "$(head -30 HANDOFF.md)"
fi

# 3. PROGRESS.md.
if [ -f PROGRESS.md ]; then
  append_section "PROGRESS.md" "$(head -20 PROGRESS.md)"
fi

# 4. this-week.md.
if [ -f this-week.md ]; then
  append_section "this-week.md" "$(head -20 this-week.md)"
fi

# 5. .claude/notes/today.md.
if [ -f .claude/notes/today.md ]; then
  append_section "Today" "$(head -15 .claude/notes/today.md)"
fi

[ -z "$CTX" ] && exit 0

CAPPED=$(printf '%s' "$CTX" | head -50)

if [ "$HAS_JQ" = "1" ]; then
  jq -n --arg ctx "$CAPPED" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
else
  printf '%s\n' "$CAPPED"
fi

exit 0
