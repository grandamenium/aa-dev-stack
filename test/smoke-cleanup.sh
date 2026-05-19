#!/usr/bin/env bash
# AA Dev Stack smoke cleanup
#
# Reverses an install for testing. Restores backups, strips merged settings,
# removes plugin caches. Idempotent.
#
# Usage:
#   bash test/smoke-cleanup.sh         (interactive: asks for confirmation)
#   bash test/smoke-cleanup.sh --yes   (non-interactive)
#   bash test/smoke-cleanup.sh --scope project --yes

set -euo pipefail

INSTALL_SCOPE="${AA_INSTALL_SCOPE:-user}"
PROJECT_DIR="${AA_PROJECT_DIR:-$PWD}"
YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) YES=1; shift ;;
    --scope)
      [[ -n "${2:-}" ]] || { echo "--scope requires one of: user, global, project, local" >&2; exit 2; }
      INSTALL_SCOPE="$2"; shift 2 ;;
    --scope=*)
      INSTALL_SCOPE="${1#--scope=}"; shift ;;
    -h|--help)
      sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

case "$INSTALL_SCOPE" in
  user|global)
    INSTALL_SCOPE="user"
    CLAUDE_DIR="${AA_CLAUDE_DIR:-$HOME/.claude}"
    ;;
  project|local)
    CLAUDE_DIR="${AA_CLAUDE_DIR:-$PROJECT_DIR/.claude}"
    ;;
  *)
    echo "Invalid --scope '$INSTALL_SCOPE'. Use one of: user, global, project, local" >&2
    exit 2
    ;;
esac

readonly CLAUDE_DIR
readonly BACKUP_ROOT="$CLAUDE_DIR/backups/aa-dev-stack"
readonly MARKER_FILE="$CLAUDE_DIR/.aa-dev-stack.installed"

if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[1;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi
info() { printf '%s[info]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }

if [[ "$YES" != "1" ]]; then
  printf '%sThis will reverse the AA Dev Stack install. Continue? [y/N] %s' "$C_YEL" "$C_RST"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]] || { info "Cancelled"; exit 0; }
fi

# 1. Restore CLAUDE.md from most recent backup (or strip fenced block)
if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
  marker_start="<!-- BEGIN: aa-dev-stack baseline (managed; do not edit between markers) -->"
  marker_end="<!-- END: aa-dev-stack baseline -->"
  if grep -qF "$marker_start" "$CLAUDE_DIR/CLAUDE.md"; then
    tmp="$CLAUDE_DIR/CLAUDE.md.tmp.$$"
    awk -v start="$marker_start" -v end="$marker_end" '
      $0 == start { skipping = 1; next }
      skipping && $0 == end { skipping = 0; next }
      !skipping { print }
    ' "$CLAUDE_DIR/CLAUDE.md" > "$tmp"
    mv "$tmp" "$CLAUDE_DIR/CLAUDE.md"
    ok "Stripped AA fenced block from CLAUDE.md"
  fi
fi

# 2. Strip AA additions from settings.json
if [[ -f "$CLAUDE_DIR/settings.json" ]] && command -v jq >/dev/null 2>&1; then
  tmp="$CLAUDE_DIR/settings.json.tmp.$$"
  jq '
    .mcpServers |= (
      if . == null then null
      else
        del(.["agent-architects"], .sentry, .supabase, .railway, .posthog, .apify, .resend)
      end
    )
    | if .mcpServers == {} then del(.mcpServers) else . end
    | .enabledPlugins |= (
        if . == null then null
        else with_entries(select(.key | startswith("aa-dev-stack") | not))
        end
      )
    | if .enabledPlugins == {} then del(.enabledPlugins) else . end
  ' "$CLAUDE_DIR/settings.json" > "$tmp"
  mv "$tmp" "$CLAUDE_DIR/settings.json"
  ok "Stripped AA additions from settings.json"
fi

# 3. Remove AA-specific state files
for f in "$CLAUDE_DIR/aa-hooks.json" "$MARKER_FILE"; do
  if [[ -f "$f" ]]; then
    rm -f "$f"
    ok "Removed $f"
  fi
done

# 4. Remove AA commands (only the ones we installed)
for c in aa.md aa-init.md aa-connect.md aa-hooks.md commit.md pr.md worktree.md finish.md cleanup.md; do
  if [[ -f "$CLAUDE_DIR/commands/$c" ]]; then
    rm -f "$CLAUDE_DIR/commands/$c"
  fi
done
ok "Removed AA commands from $CLAUDE_DIR/commands/"

# 5. Remove plugin cache (if Claude Code is installed and managed the plugin)
if command -v claude >/dev/null 2>&1; then
  if claude plugin uninstall aa-dev-stack 2>/dev/null; then
    ok "Uninstalled aa-dev-stack plugin via Claude Code"
  else
    info "Claude Code did not have aa-dev-stack installed (or uninstall failed silently)"
  fi
fi

# 6. Remove plugin cache dir if present
if [[ -d "$CLAUDE_DIR/plugins/cache/aa-marketplace" ]]; then
  rm -rf "$CLAUDE_DIR/plugins/cache/aa-marketplace"
  ok "Removed plugin cache"
fi

# 7. Remove seeded memory (only the file installer wrote)
if [[ -f "$CLAUDE_DIR/memory/aa-onboarding-patterns.md" ]]; then
  rm -f "$CLAUDE_DIR/memory/aa-onboarding-patterns.md"
  ok "Removed seeded memory"
fi

# 8. Leave secrets/ and backups/ alone (user data, explicit removal only)
info "Skipping ~/.claude/secrets/ (user data — remove manually if needed)"
info "Skipping ~/.claude/backups/aa-dev-stack/ (your backups — remove manually if needed)"

printf '\n%sCleanup complete. Re-run installer to reinstall.%s\n' "$C_GRN" "$C_RST"
