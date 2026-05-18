#!/usr/bin/env bash
# hooks/dangerous-bash-firewall.sh
# Blocks destructive shell commands before they execute. Narrow patterns so we
# don't trip on legitimate cleanup of project subdirectories.
set -euo pipefail

HOOK_NAME="dangerous-bash-firewall"
source "$(dirname "$0")/_lib/aa-common.sh"
aa_hook_enabled "$HOOK_NAME" || exit 0
aa_require_jq "$HOOK_NAME"

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
[ -z "$CMD" ] && exit 0

NORM=$(printf '%s' "$CMD" | tr '\n' ' ' | tr -s ' ')

block() {
  local label="$1"
  aa_log "dangerous-bash BLOCK ($label): $CMD"
  cat >&2 <<EOF
BLOCKED by dangerous-bash-firewall: $label

Command: $CMD

If you actually need to run this, execute it manually in your terminal
outside the Claude Code session. The agent is not authorized to run
destructive system-wide commands.
EOF
  exit 2
}

# 1. rm -rf against root / home / system dirs.
if printf '%s' "$NORM" | grep -qE '\brm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)[[:space:]]+([/~]|\$HOME|\$\{HOME\})([[:space:]]|$|/?\*|/$)'; then
  block "rm -rf against root, home, or system directory"
fi
if printf '%s' "$NORM" | grep -qE '\brm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*)[[:space:]]+/(etc|usr|var|bin|sbin|boot|lib|opt|root|System|Applications)(/|[[:space:]]|$)'; then
  block "rm -rf against critical system directory"
fi

# 2. Fork bomb.
if printf '%s' "$NORM" | grep -qE ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*&[[:space:]]*\}[[:space:]]*;[[:space:]]*:'; then
  block "fork bomb"
fi

# 3. dd to raw disk device.
if printf '%s' "$NORM" | grep -qE '\bdd[[:space:]]+.*of=/dev/(sd[a-z]|nvme[0-9]|disk[0-9]|hd[a-z])'; then
  block "dd write to raw disk device"
fi

# 4. mkfs / format commands.
if printf '%s' "$NORM" | grep -qE '\b(mkfs(\.[a-z0-9]+)?|format)[[:space:]]+/dev/'; then
  block "filesystem format on a device"
fi

# 5. Piping remote scripts into a shell.
if printf '%s' "$NORM" | grep -qE '\b(curl|wget|fetch)\b[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh|ksh)\b'; then
  block "piping remote script directly into a shell (curl | sh)"
fi

# 6. chmod -R 777 across a wide tree.
if printf '%s' "$NORM" | grep -qE '\bchmod[[:space:]]+(-R[[:space:]]+|--recursive[[:space:]]+)?777[[:space:]]+([/~]|\.|\$HOME)'; then
  block "chmod -R 777 against a root or home tree"
fi

# 7. Wiping git history.
if printf '%s' "$NORM" | grep -qE '\bgit[[:space:]]+(filter-branch|filter-repo)[[:space:]]+--force[[:space:]]+--all\b'; then
  block "destructive git history rewrite across all refs"
fi

# 8. Sudo password injection.
if printf '%s' "$NORM" | grep -qE 'echo[[:space:]]+[^|]+\|[[:space:]]*sudo[[:space:]]+-S\b'; then
  block "piping a password into sudo"
fi

# 9. eval with downloaded content.
if printf '%s' "$NORM" | grep -qE '\beval[[:space:]]+\$\([[:space:]]*(curl|wget)\b'; then
  block "eval of remote content"
fi

exit 0
