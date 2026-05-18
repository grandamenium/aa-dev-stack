#!/usr/bin/env bash
# hooks/test-affected-on-stop.sh
# Runs tests against files changed in this session.
# Default DISABLED in aa-hooks.json — opt-in only.
set -euo pipefail

HOOK_NAME="test-affected-on-stop"
source "$(dirname "$0")/_lib/aa-common.sh"
aa_hook_enabled "$HOOK_NAME" || exit 0
aa_require_jq "$HOOK_NAME"

INPUT=$(cat)

ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')
[ "$ACTIVE" = "true" ] && exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."')
cd "$CWD" 2>/dev/null || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs .)
  printf '{"decision":"block","reason":%s}\n' "$json_reason"
  exit 0
}

CHANGED_TS=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' || true)
CHANGED_PY=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.py$' || true)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null || true)
CHANGED_TS=$(printf '%s\n%s' "$CHANGED_TS" "$(printf '%s' "$UNTRACKED" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' || true)" | grep -v '^$' | sort -u || true)
CHANGED_PY=$(printf '%s\n%s' "$CHANGED_PY" "$(printf '%s' "$UNTRACKED" | grep -E '\.py$' || true)" | grep -v '^$' | sort -u || true)

detect_js_framework() {
  [ -f package.json ] || { echo "none"; return; }
  if grep -qE '"(jest|@jest/core)"' package.json 2>/dev/null; then
    echo "jest"; return
  fi
  if grep -qE '"vitest"' package.json 2>/dev/null; then
    echo "vitest"; return
  fi
  echo "none"
}

if [ -n "$CHANGED_TS" ]; then
  FW=$(detect_js_framework)
  case "$FW" in
    jest)
      # shellcheck disable=SC2086
      if ! OUT=$(npx --no-install jest --findRelatedTests --passWithNoTests $CHANGED_TS 2>&1); then
        REASON="jest tests failed for affected files. Fix before finishing:

$(printf '%s' "$OUT" | tail -60)"
        aa_log "test-affected BLOCK (jest)"
        emit_block "$REASON"
      fi
      ;;
    vitest)
      # shellcheck disable=SC2086
      if ! OUT=$(npx --no-install vitest related --run $CHANGED_TS 2>&1); then
        REASON="vitest tests failed for affected files. Fix before finishing:

$(printf '%s' "$OUT" | tail -60)"
        aa_log "test-affected BLOCK (vitest)"
        emit_block "$REASON"
      fi
      ;;
  esac
fi

if [ -n "$CHANGED_PY" ]; then
  if command -v pytest >/dev/null 2>&1; then
    if pytest --testmon --collect-only -q >/dev/null 2>&1; then
      if ! OUT=$(pytest --testmon 2>&1); then
        REASON="pytest (testmon) failed. Fix before finishing:

$(printf '%s' "$OUT" | tail -60)"
        aa_log "test-affected BLOCK (pytest+testmon)"
        emit_block "$REASON"
      fi
    elif pytest --picked --collect-only -q >/dev/null 2>&1; then
      if ! OUT=$(pytest --picked 2>&1); then
        REASON="pytest (picked) failed. Fix before finishing:

$(printf '%s' "$OUT" | tail -60)"
        aa_log "test-affected BLOCK (pytest+picked)"
        emit_block "$REASON"
      fi
    else
      # shellcheck disable=SC2086
      if ! OUT=$(pytest $CHANGED_PY 2>&1); then
        REASON="pytest failed on changed files. Fix before finishing:

$(printf '%s' "$OUT" | tail -60)"
        aa_log "test-affected BLOCK (pytest direct)"
        emit_block "$REASON"
      fi
    fi
  fi
fi

exit 0
