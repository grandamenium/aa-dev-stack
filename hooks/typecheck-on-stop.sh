#!/usr/bin/env bash
# hooks/typecheck-on-stop.sh
# Runs the project's type checker before allowing Claude to end its turn.
# Blocks via JSON so failure feedback is structured.
set -euo pipefail

HOOK_NAME="typecheck-on-stop"
source "$(dirname "$0")/_lib/aa-common.sh"
aa_hook_enabled "$HOOK_NAME" || exit 0
aa_require_jq "$HOOK_NAME"

INPUT=$(cat)

# CRITICAL: prevent infinite Stop-loop.
ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')
[ "$ACTIVE" = "true" ] && exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."')
cd "$CWD" 2>/dev/null || exit 0

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs .)
  printf '{"decision":"block","reason":%s}\n' "$json_reason"
  exit 0
}

# TypeScript
if [ -f tsconfig.json ]; then
  if ! command -v npx >/dev/null 2>&1; then
    exit 0
  fi
  if ! OUT=$(npx --no-install tsc --noEmit --pretty false 2>&1); then
    REASON="typecheck failed (tsc --noEmit). Fix these errors before finishing:

$(printf '%s' "$OUT" | head -60)"
    aa_log "typecheck-on-stop BLOCK (ts): $(printf '%s' "$OUT" | head -3)"
    emit_block "$REASON"
  fi
  exit 0
fi

# Python (mypy)
if [ -f pyproject.toml ] && grep -qE '^\[tool\.mypy\]' pyproject.toml 2>/dev/null; then
  if command -v mypy >/dev/null 2>&1; then
    if ! OUT=$(mypy . 2>&1); then
      REASON="mypy failed. Fix these type errors before finishing:

$(printf '%s' "$OUT" | head -60)"
      aa_log "typecheck-on-stop BLOCK (mypy): $(printf '%s' "$OUT" | head -3)"
      emit_block "$REASON"
    fi
  fi
  exit 0
fi

# Python (pyright)
if [ -f pyrightconfig.json ] && command -v pyright >/dev/null 2>&1; then
  if ! OUT=$(pyright --outputjson 2>&1); then
    REASON="pyright failed. Fix these type errors before finishing:

$(printf '%s' "$OUT" | head -60)"
    aa_log "typecheck-on-stop BLOCK (pyright): $(printf '%s' "$OUT" | head -3)"
    emit_block "$REASON"
  fi
fi

exit 0
