#!/usr/bin/env bash
# AA Dev Stack smoke test (v0.1.0 — 10 critical-path tests)
#
# Runs after installer. Reports pass/fail with concrete next steps.
# Exit 0 = all pass. Exit 1 = at least one fail.
#
# Usage:
#   bash test/smoke-test.sh

set -uo pipefail

readonly CLAUDE_DIR="${AA_CLAUDE_DIR:-$HOME/.claude}"
readonly REPO_BASE="${AA_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[1;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

PASSED=0
FAILED=0
TESTS=()

pass() { printf '%s[PASS]%s %s\n' "$C_GRN" "$C_RST" "$1"; PASSED=$((PASSED+1)); TESTS+=("PASS|$1"); }
fail() { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RST" "$1"; if [[ -n "${2:-}" ]]; then printf '       %s\n' "$2"; fi; FAILED=$((FAILED+1)); TESTS+=("FAIL|$1|${2:-}"); }
skip() { printf '%s[SKIP]%s %s — %s\n' "$C_YEL" "$C_RST" "$1" "${2:-}"; TESTS+=("SKIP|$1|${2:-}"); }
banner() { printf '\n%s━━━ %s ━━━%s\n' "$C_BLU" "$1" "$C_RST"; }

# ─── 1. Marker file exists ─────────────────────────────────────────────
banner "TEST 1: install marker"
if [[ -f "$CLAUDE_DIR/.aa-dev-stack.installed" ]]; then
  pass "install marker present at $CLAUDE_DIR/.aa-dev-stack.installed"
else
  fail "no install marker" "Run installer/install.sh first"
fi

# ─── 2. CLAUDE.md contains AA fenced block ─────────────────────────────
banner "TEST 2: CLAUDE.md has AA baseline block"
if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]] && grep -qF "BEGIN: aa-dev-stack baseline" "$CLAUDE_DIR/CLAUDE.md"; then
  pass "CLAUDE.md contains AA fenced block"
else
  fail "CLAUDE.md missing or no AA block" "Run installer/install.sh (or pass --skip-claudemd to skip)"
fi

# ─── 3. settings.json has agent-architects MCP ─────────────────────────
banner "TEST 3: settings.json has agent-architects MCP"
if [[ -f "$CLAUDE_DIR/settings.json" ]] \
   && command -v jq >/dev/null 2>&1 \
   && jq -e '.mcpServers["agent-architects"]' "$CLAUDE_DIR/settings.json" >/dev/null 2>&1; then
  pass "agent-architects MCP in settings.json"
else
  fail "agent-architects MCP missing from settings.json" "Re-run installer or check settings.json manually"
fi

# ─── 4. aa-hooks.json has 7 hooks ──────────────────────────────────────
banner "TEST 4: aa-hooks.json has 7 hooks"
if [[ -f "$CLAUDE_DIR/aa-hooks.json" ]] && command -v jq >/dev/null 2>&1; then
  count=$(jq -r '.hooks | length' "$CLAUDE_DIR/aa-hooks.json" 2>/dev/null || echo 0)
  if [[ "$count" -eq 7 ]]; then
    pass "aa-hooks.json has 7 hooks"
  else
    fail "aa-hooks.json has $count hooks, expected 7" "Delete and re-run installer"
  fi
else
  fail "aa-hooks.json missing or jq unavailable" "Re-run installer; install jq"
fi

# ─── 5. test-affected-on-stop is DISABLED by default ──────────────────
banner "TEST 5: test-affected-on-stop disabled by default"
if [[ -f "$CLAUDE_DIR/aa-hooks.json" ]] && command -v jq >/dev/null 2>&1; then
  v=$(jq -r '.hooks["test-affected-on-stop"].enabled // "missing"' "$CLAUDE_DIR/aa-hooks.json" 2>/dev/null || echo error)
  if [[ "$v" == "false" ]]; then
    pass "test-affected-on-stop is disabled by default"
  else
    fail "test-affected-on-stop should be disabled by default (got: $v)" "Run: /aa-hooks disable test-affected-on-stop"
  fi
else
  skip "test-affected-on-stop default" "aa-hooks.json missing or jq unavailable"
fi

# ─── 6. secrets/ exists at 700 ─────────────────────────────────────────
banner "TEST 6: secrets/ exists at 700"
if [[ -d "$CLAUDE_DIR/secrets" ]]; then
  perms=$(stat -f "%Lp" "$CLAUDE_DIR/secrets" 2>/dev/null || stat -c "%a" "$CLAUDE_DIR/secrets" 2>/dev/null || echo "")
  if [[ "$perms" == "700" ]]; then
    pass "secrets/ exists at 700"
  else
    fail "secrets/ permissions: $perms (want 700)" "chmod 700 $CLAUDE_DIR/secrets"
  fi
else
  fail "secrets/ does not exist" "Re-run installer"
fi

# ─── 7. secret-scan hook blocks an Anthropic API key ──────────────────
banner "TEST 7: secret-scan blocks Anthropic key pattern"
secret_scan="$REPO_BASE/hooks/secret-scan.sh"
if [[ -x "$secret_scan" ]]; then
  fake_payload='{"tool_name":"Write","tool_input":{"file_path":"/tmp/x.ts","content":"const key = \"sk-ant-api03-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\";"}}'
  set +e
  echo "$fake_payload" | bash "$secret_scan" >/dev/null 2>&1
  exit_code=$?
  set -e
  if [[ $exit_code -eq 2 ]]; then
    pass "secret-scan blocked with exit 2"
  else
    fail "secret-scan did not block (exit $exit_code, want 2)" "Check hooks/secret-scan.sh + ~/.claude/aa-hooks.json"
  fi
else
  fail "secret-scan.sh not found or not executable at $secret_scan" "chmod +x or re-clone repo"
fi

# ─── 8. dangerous-bash blocks rm -rf / ────────────────────────────────
banner "TEST 8: dangerous-bash-firewall blocks rm -rf /"
firewall="$REPO_BASE/hooks/dangerous-bash-firewall.sh"
if [[ -x "$firewall" ]]; then
  set +e
  echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | bash "$firewall" >/dev/null 2>&1
  exit_code=$?
  set -e
  if [[ $exit_code -eq 2 ]]; then
    pass "dangerous-bash-firewall blocked rm -rf /"
  else
    fail "dangerous-bash-firewall did not block (exit $exit_code, want 2)" "Check hooks/dangerous-bash-firewall.sh"
  fi
else
  fail "dangerous-bash-firewall.sh not found" "Re-clone repo"
fi

# ─── 9. /aa-hooks toggle: disable then re-enable ──────────────────────
banner "TEST 9: aa-hooks toggle state persists"
if command -v jq >/dev/null 2>&1 && [[ -f "$CLAUDE_DIR/aa-hooks.json" ]]; then
  before=$(jq -r '.hooks["secret-scan"].enabled' "$CLAUDE_DIR/aa-hooks.json")
  # Manually toggle for the test (real toggle goes through /aa-hooks command in Claude)
  tmp="$CLAUDE_DIR/aa-hooks.json.tmp.$$"
  jq '.hooks["secret-scan"].enabled = false' "$CLAUDE_DIR/aa-hooks.json" > "$tmp"
  mv "$tmp" "$CLAUDE_DIR/aa-hooks.json"
  after_disable=$(jq -r '.hooks["secret-scan"].enabled' "$CLAUDE_DIR/aa-hooks.json")
  jq '.hooks["secret-scan"].enabled = true' "$CLAUDE_DIR/aa-hooks.json" > "$tmp"
  mv "$tmp" "$CLAUDE_DIR/aa-hooks.json"
  after_restore=$(jq -r '.hooks["secret-scan"].enabled' "$CLAUDE_DIR/aa-hooks.json")
  if [[ "$after_disable" == "false" ]] && [[ "$after_restore" == "true" ]]; then
    pass "toggle state writes + reads correctly"
  else
    fail "toggle state inconsistent (disable=$after_disable, restore=$after_restore)" "Check aa-hooks.json schema"
  fi
else
  skip "aa-hooks toggle" "jq missing or aa-hooks.json missing"
fi

# ─── 10. commands installed for short names ────────────────────────────
banner "TEST 10: commands installed to ~/.claude/commands/"
expected=(aa.md aa-init.md aa-connect.md aa-hooks.md commit.md pr.md worktree.md finish.md cleanup.md)
missing_count=0
for c in "${expected[@]}"; do
  if [[ ! -f "$CLAUDE_DIR/commands/$c" ]]; then
    missing_count=$((missing_count + 1))
  fi
done
if [[ "$missing_count" -eq 0 ]]; then
  pass "all 9 commands present in $CLAUDE_DIR/commands/"
else
  fail "$missing_count commands missing from $CLAUDE_DIR/commands/" "Re-run installer (install_short_name_commands step)"
fi

# ─── REPORT ────────────────────────────────────────────────────────────
banner "SMOKE TEST REPORT"
printf 'Passed: %s%d%s   Failed: %s%d%s\n' "$C_GRN" "$PASSED" "$C_RST" "$C_RED" "$FAILED" "$C_RST"

if [[ "$FAILED" -gt 0 ]]; then
  printf '\n%sFailing tests:%s\n' "$C_RED" "$C_RST"
  for t in "${TESTS[@]}"; do
    if [[ "$t" == FAIL* ]]; then
      IFS='|' read -r _status name fix <<< "$t"
      printf '  - %s\n' "$name"
      [[ -n "$fix" ]] && printf '    %s\n' "$fix"
    fi
  done
  exit 1
fi

printf '\n%sAll smoke tests passed.%s\n' "$C_GRN" "$C_RST"
exit 0
