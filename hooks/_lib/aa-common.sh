#!/usr/bin/env bash
# Shared helpers for all AA hooks. Source this from each hook.
# Usage:
#   source "$(dirname "$0")/_lib/aa-common.sh"
#   aa_hook_enabled "secret-scan" || exit 0

AA_HOOKS_CONFIG="${AA_HOOKS_CONFIG:-$HOME/.claude/aa-hooks.json}"

# Return 0 if hook is enabled. Default to enabled (fail open on missing config).
# Project-level override at ${CLAUDE_PROJECT_DIR}/.claude/aa-hooks.json takes
# precedence over global.
aa_hook_enabled() {
  local name="$1"
  local project_cfg="${CLAUDE_PROJECT_DIR:-.}/.claude/aa-hooks.json"

  if [ -f "$project_cfg" ] && command -v jq >/dev/null 2>&1; then
    local override
    override=$(jq -r --arg n "$name" '.hooks[$n].enabled // empty' "$project_cfg" 2>/dev/null)
    if [ -n "$override" ]; then
      [ "$override" = "true" ]
      return $?
    fi
  fi

  [ ! -f "$AA_HOOKS_CONFIG" ] && return 0
  command -v jq >/dev/null 2>&1 || return 0
  local enabled
  enabled=$(jq -r --arg n "$name" '.hooks[$n].enabled // true' "$AA_HOOKS_CONFIG" 2>/dev/null)
  [ "$enabled" = "true" ]
}

# Exit gracefully if jq is missing (rather than crash Claude session).
aa_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "aa-hooks: jq not installed; skipping $1" >&2
    exit 0
  fi
}

# Append a line to the AA hooks log.
aa_log() {
  local dir="$HOME/.claude/logs"
  mkdir -p "$dir" 2>/dev/null || return 0
  echo "[$(date -Iseconds 2>/dev/null || date)] $*" >> "$dir/aa-hooks.log"
}
