#!/usr/bin/env bash
# hooks/auto-format.sh
# Format the file Claude just wrote. Detects formatter per project + extension.
# Non-blocking: any failure becomes a stderr note, never an exit 2.
set -euo pipefail

HOOK_NAME="auto-format"
source "$(dirname "$0")/_lib/aa-common.sh"
aa_hook_enabled "$HOOK_NAME" || exit 0
aa_require_jq "$HOOK_NAME"

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."')

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

EXT="${FILE##*.}"

project_has() {
  local target="$1"
  local dir="$CWD"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    [ -e "$dir/$target" ] && return 0
    dir=$(dirname "$dir")
  done
  return 1
}

run_silent() {
  local out
  if ! out=$("$@" 2>&1); then
    echo "auto-format: $1 failed on $FILE" >&2
    echo "$out" | head -10 >&2
    return 1
  fi
  return 0
}

case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs)
    if project_has biome.json || project_has biome.jsonc; then
      command -v biome >/dev/null 2>&1 && run_silent biome format --write "$FILE" || true
    elif project_has .prettierrc || project_has .prettierrc.json || project_has .prettierrc.js \
      || project_has .prettierrc.yaml || project_has .prettierrc.yml || project_has prettier.config.js \
      || project_has prettier.config.mjs; then
      command -v prettier >/dev/null 2>&1 && run_silent prettier --write --log-level=silent "$FILE" || true
    else
      command -v biome >/dev/null 2>&1 && run_silent biome format --write "$FILE" 2>/dev/null \
        || command -v prettier >/dev/null 2>&1 && run_silent prettier --write --log-level=silent "$FILE" 2>/dev/null || true
    fi
    ;;
  json|jsonc)
    if project_has biome.json; then
      command -v biome >/dev/null 2>&1 && run_silent biome format --write "$FILE" || true
    else
      command -v prettier >/dev/null 2>&1 && run_silent prettier --write --log-level=silent "$FILE" || true
    fi
    ;;
  md|mdx|yaml|yml|css|scss|html)
    command -v prettier >/dev/null 2>&1 && run_silent prettier --write --log-level=silent "$FILE" || true
    ;;
  py)
    if command -v ruff >/dev/null 2>&1; then
      run_silent ruff format "$FILE" || true
    elif command -v black >/dev/null 2>&1; then
      run_silent black --quiet "$FILE" || true
    elif command -v uv >/dev/null 2>&1; then
      run_silent uv tool run ruff format "$FILE" || true
    fi
    ;;
  go)
    command -v gofmt >/dev/null 2>&1 && run_silent gofmt -w "$FILE" || true
    command -v goimports >/dev/null 2>&1 && run_silent goimports -w "$FILE" || true
    ;;
  rs)
    command -v rustfmt >/dev/null 2>&1 && run_silent rustfmt --edition 2021 "$FILE" || true
    ;;
  sh|bash)
    command -v shfmt >/dev/null 2>&1 && run_silent shfmt -w -i 2 "$FILE" || true
    ;;
esac

exit 0
