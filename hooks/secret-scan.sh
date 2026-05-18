#!/usr/bin/env bash
# hooks/secret-scan.sh
# Blocks file writes containing credential patterns. Exit 2 + stderr feeds Claude
# a clear "use env vars instead" message.
set -euo pipefail

HOOK_NAME="secret-scan"
source "$(dirname "$0")/_lib/aa-common.sh"
aa_hook_enabled "$HOOK_NAME" || exit 0
aa_require_jq "$HOOK_NAME"

INPUT=$(cat)

CONTENT=$(printf '%s' "$INPUT" | jq -r '
  [
    .tool_input.content // empty,
    .tool_input.new_string // empty,
    (.tool_input.edits // [] | map(.new_string) | join("\n"))
  ] | join("\n")
')

[ -z "$CONTENT" ] && exit 0

PATTERNS=(
  'Anthropic API key|sk-ant-(api|admin)[0-9]{2}-[A-Za-z0-9_-]{80,}'
  'OpenAI API key|sk-(proj-)?[A-Za-z0-9_-]{40,}'
  'OpenAI legacy key|sk-[A-Za-z0-9]{48}'
  'AWS access key ID|AKIA[0-9A-Z]{16}'
  'AWS secret access key|aws_secret_access_key\s*[:=]\s*["'"'"']?[A-Za-z0-9/+=]{40}'
  'Stripe live secret|sk_live_[0-9a-zA-Z]{24,}'
  'Stripe restricted key|rk_live_[0-9a-zA-Z]{24,}'
  'GitHub PAT|ghp_[A-Za-z0-9]{36}'
  'GitHub OAuth|gho_[A-Za-z0-9]{36}'
  'GitHub server token|ghs_[A-Za-z0-9]{36}'
  'GitHub fine-grained PAT|github_pat_[A-Za-z0-9_]{82}'
  'Slack user token|xox[pboars]-[0-9]+-[0-9]+-[0-9]+-[A-Za-z0-9]+'
  'Slack webhook|hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+'
  'Google API key|AIza[0-9A-Za-z_-]{35}'
  'Private key (PEM)|-----BEGIN (RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'
  'Postgres connection|postgres(ql)?://[^/[:space:]]+:[^@[:space:]]+@'
  'MongoDB connection|mongodb(\+srv)?://[^/[:space:]]+:[^@[:space:]]+@'
  'Generic high-entropy secret|(api[_-]?key|secret|token|password)\s*[:=]\s*["'"'"'][A-Za-z0-9/+=_-]{32,}["'"'"']'
)

# Strip env var refs before matching to kill false positives.
SANITIZED=$(printf '%s' "$CONTENT" \
  | sed -E 's/process\.env\.[A-Z_][A-Z0-9_]*//g' \
  | sed -E 's/\$\{[A-Z_][A-Z0-9_]*\}//g' \
  | sed -E 's/\$[A-Z_][A-Z0-9_]*//g')

for entry in "${PATTERNS[@]}"; do
  label="${entry%%|*}"
  regex="${entry#*|}"
  if printf '%s' "$SANITIZED" | grep -qE "$regex"; then
    aa_log "secret-scan BLOCK: $label"
    cat >&2 <<EOF
BLOCKED by secret-scan: detected pattern "$label".

Do not hardcode credentials. Use one of:
  - Environment variables: process.env.X (Node) / os.environ["X"] (Python)
  - A .env file (gitignored) loaded via dotenv
  - The platform secret manager (Railway / Vercel / AWS Secrets Manager)

If this is a false positive (placeholder, example, or sample), rename the
variable to make intent obvious (e.g. EXAMPLE_KEY_DO_NOT_USE).
EOF
    exit 2
  fi
done

exit 0
