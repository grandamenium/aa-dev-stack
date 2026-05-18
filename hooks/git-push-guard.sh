#!/usr/bin/env bash
# hooks/git-push-guard.sh
# Blocks: any --force push, any push to a protected branch.
# Allows: --force-with-lease, normal pushes to feature branches.
set -euo pipefail

HOOK_NAME="git-push-guard"
source "$(dirname "$0")/_lib/aa-common.sh"
aa_hook_enabled "$HOOK_NAME" || exit 0
aa_require_jq "$HOOK_NAME"

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
[ -z "$CMD" ] && exit 0

printf '%s' "$CMD" | grep -qE '\bgit[[:space:]]+push\b' || exit 0

NORM=$(printf '%s' "$CMD" | tr '\n' ' ' | tr -s ' ')

# 1. --force / -f without --force-with-lease.
if printf '%s' "$NORM" | grep -qE '\bgit[[:space:]]+push\b.*(--force\b|[[:space:]]-f\b|[[:space:]]-f$)' \
   && ! printf '%s' "$NORM" | grep -q -- '--force-with-lease'; then
  cat >&2 <<'EOF'
BLOCKED by git-push-guard: refusing --force push.

If you genuinely need to rewrite remote history, use:
  git push --force-with-lease

That refuses to clobber commits you don't know about. If you want to bypass
this guard entirely, run the push manually in your terminal outside Claude.
EOF
  aa_log "git-push BLOCK: --force without lease: $CMD"
  exit 2
fi

# 2. Push to a protected branch.
if printf '%s' "$NORM" | grep -qE '\bgit[[:space:]]+push\b[[:space:]]+[A-Za-z0-9._/-]+[[:space:]]+(\+)?([A-Za-z0-9._/-]+:)?(main|master|production|prod|release(/[A-Za-z0-9._/-]+)?)([[:space:]]|$)'; then
  cat >&2 <<'EOF'
BLOCKED by git-push-guard: direct push to a protected branch.

Workflow:
  1. Push your branch:    git push -u origin <feature-branch>
  2. Open a PR:           gh pr create
  3. Merge via PR review.

If you need to bypass this (hotfix, release), run the push manually in your
terminal outside Claude.
EOF
  aa_log "git-push BLOCK: protected branch: $CMD"
  exit 2
fi

# 3. Bare `git push` while on a protected branch.
if printf '%s' "$NORM" | grep -qE '^\s*git[[:space:]]+push\s*$'; then
  CUR=$(git -C "$(printf '%s' "$INPUT" | jq -r '.cwd // "."')" branch --show-current 2>/dev/null || echo "")
  case "$CUR" in
    main|master|production|prod|release/*)
      cat >&2 <<EOF
BLOCKED by git-push-guard: bare \`git push\` while on protected branch "$CUR".
Switch to a feature branch and open a PR.
EOF
      aa_log "git-push BLOCK: bare push on protected branch $CUR"
      exit 2
      ;;
  esac
fi

exit 0
