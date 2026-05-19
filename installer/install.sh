#!/usr/bin/env bash
# AA Dev Stack installer (v0.1.2)
#
# Does the work `claude plugin install` doesn't:
#   - Merges baseline CLAUDE.md into the selected Claude config dir (fenced markers, idempotent)
#   - Deep-merges settings-template.json into the selected settings.json
#   - Creates secrets/ at 700 in the selected Claude config dir
#   - Writes aa-hooks.json (default state: 6 enabled, test-affected-on-stop disabled)
#   - Copies command files to commands/ for short names
#   - BUNDLES community skills via `claude plugin install` calls
#   - Installs GSD-classic via npm
#   - Pre-seeds memory/aa-onboarding-patterns.md
#   - Writes .aa-dev-stack.installed marker (git_sha + timestamp)
#
# Idempotent: safe to re-run.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/grandamenium/aa-dev-stack/main/installer/install.sh | bash
#   curl -fsSL ... | bash -s -- --dry-run
#   curl -fsSL ... | bash -s -- --scope user
#   curl -fsSL ... | bash -s -- --scope project
#   curl -fsSL ... | bash -s -- --skip-community-skills

set -euo pipefail

# ─── constants ─────────────────────────────────────────────────────────
readonly SCRIPT_VERSION="0.1.2"
readonly PLUGIN_NAME="aa-dev-stack"
readonly REPO_URL="${AA_REPO_URL:-https://github.com/grandamenium/aa-dev-stack.git}"
readonly REF="${AA_REF:-}"
readonly TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
readonly REQUIRED_TOOLS=(git jq curl)

# ─── flags ─────────────────────────────────────────────────────────────
DRY_RUN=0
SKIP_CLAUDEMD=0
SKIP_COMMUNITY=0
SKIP_GSD=0
FORCE="${AA_FORCE:-0}"
INSTALL_SCOPE="${AA_INSTALL_SCOPE:-user}"
PROJECT_DIR="${AA_PROJECT_DIR:-$PWD}"

CLAUDE_DIR=""
BACKUP_ROOT=""
BACKUP_DIR=""
MARKER_FILE=""
HOOKS_INSTALL_DIR=""
PLUGIN_SCOPE=""
SCOPE_LABEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)               DRY_RUN=1; shift ;;
    --scope)
      [[ -n "${2:-}" ]] || { echo "--scope requires one of: user, global, project, local" >&2; exit 2; }
      INSTALL_SCOPE="$2"; shift 2 ;;
    --scope=*)
      INSTALL_SCOPE="${1#--scope=}"; shift ;;
    --skip-claudemd)         SKIP_CLAUDEMD=1; shift ;;
    --skip-community-skills) SKIP_COMMUNITY=1; shift ;;
    --skip-gsd)              SKIP_GSD=1; shift ;;
    --force)                 FORCE=1; shift ;;
    -h|--help)
      sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

resolve_install_scope() {
  case "$INSTALL_SCOPE" in
    user|global)
      INSTALL_SCOPE="user"
      PLUGIN_SCOPE="user"
      SCOPE_LABEL="global/user"
      CLAUDE_DIR="${AA_CLAUDE_DIR:-$HOME/.claude}"
      ;;
    project|local)
      PLUGIN_SCOPE="$INSTALL_SCOPE"
      SCOPE_LABEL="$INSTALL_SCOPE"
      CLAUDE_DIR="${AA_CLAUDE_DIR:-$PROJECT_DIR/.claude}"
      ;;
    *)
      echo "Invalid --scope '$INSTALL_SCOPE'. Use one of: user, global, project, local" >&2
      exit 2
      ;;
  esac

  BACKUP_ROOT="$CLAUDE_DIR/backups/$PLUGIN_NAME"
  BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
  MARKER_FILE="$CLAUDE_DIR/.aa-dev-stack.installed"
  HOOKS_INSTALL_DIR="$CLAUDE_DIR/hooks/$PLUGIN_NAME"
}

resolve_install_scope

# ─── colors ────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[1;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';   C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
info()  { printf '%s[info]%s %s\n'  "$C_BLU" "$C_RST" "$*"; }
ok()    { printf '%s[ ok ]%s %s\n'  "$C_GRN" "$C_RST" "$*"; }
warn()  { printf '%s[warn]%s %s\n'  "$C_YEL" "$C_RST" "$*" >&2; }
err()   { printf '%s[fail]%s %s\n'  "$C_RED" "$C_RST" "$*" >&2; }
step()  { printf '\n%s━━ %s %s\n'   "$C_BLU" "$*"          "$C_RST"; }
run()   { if [[ "$DRY_RUN" == "1" ]]; then printf '%s$ %s%s\n' "$C_DIM" "$*" "$C_RST"; else eval "$@"; fi; }

# ─── trap: cleanup on error ────────────────────────────────────────────
TMP_WORK=""
INSTALL_KIND="fresh"
cleanup() {
  local code=$?
  if [[ -n "$TMP_WORK" ]] && [[ -d "$TMP_WORK" ]]; then
    rm -rf "$TMP_WORK"
  fi
  if [[ $code -ne 0 ]]; then
    err "Install failed (exit $code). Your backups are in: $BACKUP_DIR"
    err "Restore with:  cp -r $BACKUP_DIR/* $CLAUDE_DIR/"
  fi
  exit $code
}
trap cleanup EXIT INT TERM

# ─── preflight ─────────────────────────────────────────────────────────
preflight() {
  step "Preflight checks"

  local os_name
  os_name="$(uname -s)"
  case "$os_name" in
    Darwin|Linux) ok "OS: $os_name" ;;
    *)            err "Unsupported OS: $os_name (need Darwin or Linux)"; exit 1 ;;
  esac

  local missing=()
  for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing required tools: ${missing[*]}"
    err "Install on macOS:  brew install ${missing[*]}"
    err "Install on Ubuntu: sudo apt-get install -y ${missing[*]}"
    exit 1
  fi
  ok "Tools available: ${REQUIRED_TOOLS[*]}"

  if command -v claude >/dev/null 2>&1; then
    local cc_version
    cc_version="$(claude --version 2>/dev/null | awk '{print $1}' || echo unknown)"
    ok "Claude Code detected: $cc_version"
  else
    warn "Claude Code not found in PATH. Install it: https://claude.com/code"
    warn "Continuing anyway. Run \`claude plugin install\` after Claude Code is installed."
  fi

  info "Install scope: $SCOPE_LABEL"
  info "Claude config target: $CLAUDE_DIR"
  if [[ "$INSTALL_SCOPE" != "user" ]]; then
    info "Project root: $PROJECT_DIR"
  fi

  if [[ ! -d "$CLAUDE_DIR" ]]; then
    info "Creating $CLAUDE_DIR (first-time setup for selected scope)"
    run "mkdir -p '$CLAUDE_DIR'"
  fi
  if [[ "$DRY_RUN" == "1" ]] && [[ ! -d "$CLAUDE_DIR" ]]; then
    info "(dry-run) target does not exist yet; skipping writable check"
    return 0
  fi
  if [[ ! -w "$CLAUDE_DIR" ]]; then
    err "$CLAUDE_DIR is not writable. Check permissions."
    exit 1
  fi
  ok "$CLAUDE_DIR is writable"
}

# ─── fetch plugin source ───────────────────────────────────────────────
fetch_source() {
  step "Fetching plugin source"
  TMP_WORK="$(mktemp -d -t aa-dev-stack.XXXXXX)"
  ok "Working dir: $TMP_WORK"

  local clone_args=(--depth 1)
  if [[ -n "$REF" ]]; then
    clone_args+=(--branch "$REF")
  fi

  git clone "${clone_args[@]}" "$REPO_URL" "$TMP_WORK/src" >/dev/null 2>&1
  local sha
  sha="$(git -C "$TMP_WORK/src" rev-parse --short HEAD)"
  ok "Cloned at commit $sha"
}

# ─── upgrade vs fresh detection ────────────────────────────────────────
detect_install_kind() {
  step "Detecting install kind"
  if [[ -f "$MARKER_FILE" ]]; then
    local prev_version prev_date prev_sha
    prev_version="$(jq -r '.version // "unknown"' "$MARKER_FILE" 2>/dev/null || echo unknown)"
    prev_date="$(jq -r '.installed_at // "unknown"' "$MARKER_FILE" 2>/dev/null || echo unknown)"
    prev_sha="$(jq -r '.git_sha // "unknown"' "$MARKER_FILE" 2>/dev/null || echo unknown)"
    info "Existing install detected:"
    info "  version:      $prev_version"
    info "  installed_at: $prev_date"
    info "  git_sha:      $prev_sha"
    info "→ Performing UPGRADE (backup will be taken before overwrite)"
    INSTALL_KIND="upgrade"
  else
    info "→ Performing FRESH INSTALL"
    INSTALL_KIND="fresh"
  fi
}

# ─── backup ────────────────────────────────────────────────────────────
backup_existing() {
  step "Backing up existing files"
  run "mkdir -p '$BACKUP_DIR'"

  local to_back_up=(
    "CLAUDE.md"
    "settings.json"
    "settings.local.json"
    "aa-hooks.json"
  )

  local backed_up=0
  for rel in "${to_back_up[@]}"; do
    local full="$CLAUDE_DIR/$rel"
    if [[ -e "$full" ]]; then
      run "cp -p '$full' '$BACKUP_DIR/$rel'"
      ok "backed up: $rel"
      backed_up=$((backed_up + 1))
    fi
  done

  if [[ $backed_up -eq 0 ]]; then
    info "Nothing to back up (clean directory)"
    run "rmdir '$BACKUP_DIR' 2>/dev/null || true"
  else
    ok "Backups in: $BACKUP_DIR"
  fi

  if [[ -d "$BACKUP_ROOT" ]]; then
    local n
    n="$(ls -1 "$BACKUP_ROOT" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$n" -gt 10 ]]; then
      local to_remove=$((n - 10))
      ls -1t "$BACKUP_ROOT" | tail -n "$to_remove" | while read -r old; do
        run "rm -rf '$BACKUP_ROOT/$old'"
      done
      info "Pruned $to_remove old backup(s); keeping most recent 10"
    fi
  fi
}

# ─── CLAUDE.md merge ───────────────────────────────────────────────────
install_claudemd() {
  [[ "$SKIP_CLAUDEMD" == "1" ]] && { info "Skipping CLAUDE.md (per --skip-claudemd)"; return 0; }

  step "Installing baseline CLAUDE.md block"
  local target="$CLAUDE_DIR/CLAUDE.md"
  local source="$TMP_WORK/src/baseline-claude-md.md"
  local marker_start="<!-- BEGIN: aa-dev-stack baseline (managed; do not edit between markers) -->"
  local marker_end="<!-- END: aa-dev-stack baseline -->"

  if [[ ! -f "$source" ]]; then
    warn "Plugin has no baseline-claude-md.md to install — skipping"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would merge: $source → $target"
    return 0
  fi

  local block
  block="$(printf '%s\n%s\n%s\n' "$marker_start" "$(cat "$source")" "$marker_end")"

  if [[ -f "$target" ]] && grep -qF "$marker_start" "$target"; then
    local tmp="${target}.tmp.$$"
    local block_file="${target}.block.$$"
    printf '%s\n' "$block" > "$block_file"
    awk -v start="$marker_start" -v end="$marker_end" -v block_file="$block_file" '
      $0 == start {
        while ((getline line < block_file) > 0) print line
        close(block_file)
        skipping = 1
        next
      }
      skipping && $0 == end { skipping = 0; next }
      !skipping { print }
    ' "$target" > "$tmp"
    rm -f "$block_file"
    mv "$tmp" "$target"
    ok "Updated managed block in $target"
  elif [[ -f "$target" ]]; then
    printf '\n%s\n' "$block" >> "$target"
    ok "Appended managed block to $target"
  else
    printf '%s\n' "$block" > "$target"
    ok "Created $target with baseline"
  fi
}

# ─── settings.json deep-merge ──────────────────────────────────────────
install_settings() {
  step "Merging settings.json"
  local target="$CLAUDE_DIR/settings.json"
  local fragment="$TMP_WORK/src/settings-template.json"

  if [[ ! -f "$fragment" ]]; then
    warn "No settings-template.json in plugin — skipping settings merge"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would merge: $fragment INTO $target"
    return 0
  fi

  if [[ ! -f "$target" ]]; then
    echo '{}' > "$target"
  fi

  if ! jq empty "$target" 2>/dev/null; then
    err "$target is not valid JSON. Backup at $BACKUP_DIR. Aborting."
    exit 1
  fi
  if ! jq empty "$fragment" 2>/dev/null; then
    err "$fragment is not valid JSON. Plugin is broken; please report."
    exit 1
  fi

  local tmp="${target}.tmp.$$"
  jq -n \
    --slurpfile user "$target" \
    --slurpfile plugin "$fragment" \
    '
    ($user[0]) as $u |
    ($plugin[0]) as $p |
    ($u * $p) as $merged |
    $merged
    | if ($p.permissions.additionalAllow // null) then
        .permissions.additionalAllow = (
          ((($u.permissions.additionalAllow // []) + ($p.permissions.additionalAllow // [])) | unique)
        )
      else . end
    | if ($p.mcpServers // null) then
        .mcpServers = (($p.mcpServers // {}) * ($u.mcpServers // {}))
      else . end
    ' > "$tmp"

  if ! jq empty "$tmp" 2>/dev/null; then
    err "Merge produced invalid JSON. Aborting (your settings are untouched)."
    rm -f "$tmp"
    exit 1
  fi

  mv "$tmp" "$target"
  ok "Merged: $target"
}

# ─── hook scripts + Claude hook settings ───────────────────────────────
install_hook_scripts() {
  step "Installing hook scripts"
  local src="$TMP_WORK/src/hooks"

  [[ ! -d "$src" ]] && { warn "No hooks/ in plugin"; return 0; }

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would copy hook scripts to $HOOKS_INSTALL_DIR"
    return 0
  fi

  rm -rf "$HOOKS_INSTALL_DIR"
  mkdir -p "$HOOKS_INSTALL_DIR"
  cp -R "$src"/. "$HOOKS_INSTALL_DIR"/
  find "$HOOKS_INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;
  ok "Copied hook scripts to $HOOKS_INSTALL_DIR"
}

install_hook_settings() {
  step "Activating Claude hook settings"
  local target="$CLAUDE_DIR/settings.json"

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would merge AA hook lifecycle config into $target"
    return 0
  fi

  if [[ ! -f "$target" ]]; then
    echo '{}' > "$target"
  fi

  if ! jq empty "$target" 2>/dev/null; then
    err "$target is not valid JSON. Backup at $BACKUP_DIR. Aborting."
    exit 1
  fi

  local secret_scan dangerous_bash git_push auto_format typecheck affected_tests session_start
  secret_scan="AA_HOOKS_CONFIG='$CLAUDE_DIR/aa-hooks.json' bash '$HOOKS_INSTALL_DIR/secret-scan.sh'"
  dangerous_bash="AA_HOOKS_CONFIG='$CLAUDE_DIR/aa-hooks.json' bash '$HOOKS_INSTALL_DIR/dangerous-bash-firewall.sh'"
  git_push="AA_HOOKS_CONFIG='$CLAUDE_DIR/aa-hooks.json' bash '$HOOKS_INSTALL_DIR/git-push-guard.sh'"
  auto_format="AA_HOOKS_CONFIG='$CLAUDE_DIR/aa-hooks.json' bash '$HOOKS_INSTALL_DIR/auto-format.sh'"
  typecheck="AA_HOOKS_CONFIG='$CLAUDE_DIR/aa-hooks.json' bash '$HOOKS_INSTALL_DIR/typecheck-on-stop.sh'"
  affected_tests="AA_HOOKS_CONFIG='$CLAUDE_DIR/aa-hooks.json' bash '$HOOKS_INSTALL_DIR/test-affected-on-stop.sh'"
  session_start="AA_HOOKS_CONFIG='$CLAUDE_DIR/aa-hooks.json' bash '$HOOKS_INSTALL_DIR/session-start-context.sh'"

  local tmp="${target}.tmp.$$"
  jq \
    --arg secret_scan "$secret_scan" \
    --arg dangerous_bash "$dangerous_bash" \
    --arg git_push "$git_push" \
    --arg auto_format "$auto_format" \
    --arg typecheck "$typecheck" \
    --arg affected_tests "$affected_tests" \
    --arg session_start "$session_start" \
    '
    def aa_hook($command; $timeout):
      if $timeout == "" then
        {"type":"command","command":$command}
      else
        {"type":"command","command":$command,"timeout":($timeout | tonumber)}
      end;
    def append_unique($items):
      . as $existing
      | reduce $items[] as $item ($existing; if any(.[]?; . == $item) then . else . + [$item] end);

    .hooks = (.hooks // {})
    | .hooks.PreToolUse = ((.hooks.PreToolUse // []) | append_unique([
        {"matcher":"Edit|Write|MultiEdit","hooks":[aa_hook($secret_scan; "")]},
        {"matcher":"Bash","hooks":[aa_hook($dangerous_bash; ""), aa_hook($git_push; "")]}
      ]))
    | .hooks.PostToolUse = ((.hooks.PostToolUse // []) | append_unique([
        {"matcher":"Edit|Write|MultiEdit","hooks":[aa_hook($auto_format; "")]}
      ]))
    | .hooks.Stop = ((.hooks.Stop // []) | append_unique([
        {"hooks":[aa_hook($typecheck; "20"), aa_hook($affected_tests; "20")]}
      ]))
    | .hooks.SessionStart = ((.hooks.SessionStart // []) | append_unique([
        {"matcher":"startup|resume|clear","hooks":[aa_hook($session_start; "")]}
      ]))
    ' "$target" > "$tmp"

  if ! jq empty "$tmp" 2>/dev/null; then
    err "Hook settings merge produced invalid JSON. Aborting (your settings are untouched)."
    rm -f "$tmp"
    exit 1
  fi

  mv "$tmp" "$target"
  ok "Activated AA hooks in $target"
}

# ─── secrets directory ─────────────────────────────────────────────────
install_secrets_dir() {
  step "Provisioning secrets/"
  local dir="$CLAUDE_DIR/secrets"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would create $dir if missing"
    info "(dry-run) would set permissions: 700 on dir, 600 on files"
    return 0
  fi

  if [[ ! -d "$dir" ]]; then
    run "mkdir -p '$dir'"
    ok "Created $dir"
  else
    info "$dir already exists"
  fi
  run "chmod 700 '$dir'"

  if [[ "$DRY_RUN" != "1" ]] && [[ -d "$dir" ]]; then
    find "$dir" -type f -exec chmod 600 {} \; 2>/dev/null || true
  fi
  ok "Permissions: 700 on dir, 600 on files"

  local readme="$dir/README.md"
  if [[ ! -f "$readme" ]] && [[ "$DRY_RUN" != "1" ]]; then
    cat > "$readme" <<'EOF'
# Claude secrets directory

Per-service credentials managed by `/aa-connect`.

- File names: `<service>.env` (e.g. `supabase.env`, `railway.env`)
- File format: shell `KEY=value` per line
- Permissions: this dir is 700, each file is 600
- Read by MCP servers via `envFile` in settings.json
- Never commit these files
EOF
    chmod 600 "$readme"
  fi
}

# ─── aa-hooks.json default state ───────────────────────────────────────
install_aa_hooks_state() {
  step "Writing aa-hooks.json default state"
  local target="$CLAUDE_DIR/aa-hooks.json"

  if [[ -f "$target" ]]; then
    info "$target already exists, preserving"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would write $target"
    return 0
  fi

  cat > "$target" <<'EOF'
{
  "version": 1,
  "hooks": {
    "secret-scan":             {"enabled": true},
    "dangerous-bash-firewall": {"enabled": true},
    "git-push-guard":          {"enabled": true},
    "auto-format":             {"enabled": true},
    "typecheck-on-stop":       {"enabled": true},
    "test-affected-on-stop":   {"enabled": false},
    "session-start-context":   {"enabled": true}
  }
}
EOF
  ok "Wrote $target"
}

# ─── copy commands for short names ─────────────────────────────────────
install_short_name_commands() {
  step "Installing commands for short names"
  local src="$TMP_WORK/src/commands"
  local dst="$CLAUDE_DIR/commands"

  [[ ! -d "$src" ]] && { warn "No commands/ in plugin"; return 0; }

  run "mkdir -p '$dst'"

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would copy $(ls "$src" | wc -l | tr -d ' ') commands"
    return 0
  fi

  for cmd in "$src"/*.md; do
    [[ -f "$cmd" ]] || continue
    local name
    name="$(basename "$cmd")"
    cp "$cmd" "$dst/$name"
  done
  ok "Copied $(ls "$src" | wc -l | tr -d ' ') commands to $dst"
}

# ─── pre-seed memory for /promote-memory (v1.1) ────────────────────────
install_seed_memory() {
  step "Pre-seeding memory/ for future /promote-memory"
  local dir="$CLAUDE_DIR/memory"
  local file="$dir/aa-onboarding-patterns.md"

  run "mkdir -p '$dir'"

  if [[ -f "$file" ]]; then
    info "$file already exists, preserving"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would write $file"
    return 0
  fi

  cat > "$file" <<'EOF'
# AA Onboarding Patterns

Pre-seeded memory file so /promote-memory has material to work with on first run.
Delete or edit freely after your first real session.

## Pattern: AA install discipline

When working on AA projects, always start with:
1. Read CLAUDE.md (global + project)
2. git status / git log --oneline -10
3. Check active hooks: /aa-hooks list

## Pattern: Lazy service connect

Never paste API keys directly into chat or commit them. Use:
  /aa-connect <service>

Each service has its own onboarding flow. Keys land in the selected Claude secrets directory at 600.
EOF
  ok "Seeded $file"
}

# ─── community skills bundling ─────────────────────────────────────────
install_community_skills() {
  [[ "$SKIP_COMMUNITY" == "1" ]] && { info "Skipping community skills (per --skip-community-skills)"; return 0; }

  step "Bundling community skills"

  if ! command -v claude >/dev/null 2>&1; then
    warn "Claude Code not in PATH — skipping community skill install"
    warn "Run later: bash $TMP_WORK/installer/install.sh --skip-claudemd"
    return 0
  fi

  local manifest="$TMP_WORK/src/community-skills.json"
  if [[ ! -f "$manifest" ]]; then
    warn "No community-skills.json in plugin — skipping"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    info "(dry-run) would install community skills from $manifest"
    return 0
  fi

  local marketplaces plugins legacy_skills
  marketplaces=$(jq -r '.marketplaces_to_add[].spec' "$manifest" 2>/dev/null || true)
  plugins=$(jq -r '.plugins_to_install[] | "\(.name)@\(.marketplace)"' "$manifest" 2>/dev/null || true)
  legacy_skills=$(jq -c '.legacy_skills_to_install[]?' "$manifest" 2>/dev/null || true)

  if [[ -n "$marketplaces" ]]; then
    while IFS= read -r mp; do
      [[ -z "$mp" ]] && continue
      if claude plugin marketplace add --scope "$PLUGIN_SCOPE" "$mp" >/dev/null 2>&1; then
        ok "marketplace: $mp"
      else
        warn "marketplace add failed: $mp (may already be added or repo unavailable)"
      fi
    done <<< "$marketplaces"
  fi

  if [[ -n "$plugins" ]]; then
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      if claude plugin install --scope "$PLUGIN_SCOPE" "$p" >/dev/null 2>&1; then
        ok "plugin: $p"
      else
        warn "plugin install failed: $p (may already be installed or marketplace mismatch)"
      fi
    done <<< "$plugins"
  fi

  if [[ -n "$legacy_skills" ]]; then
    local skills_dir="$CLAUDE_DIR/skills"
    mkdir -p "$skills_dir"
    while IFS= read -r skill; do
      [[ -z "$skill" ]] && continue
      local name repo path work target
      name="$(jq -r '.name' <<< "$skill")"
      repo="$(jq -r '.repo' <<< "$skill")"
      path="$(jq -r '.path' <<< "$skill")"
      work="$(mktemp -d -t aa-skill.XXXXXX)"
      target="$skills_dir/$name"
      if git clone --depth 1 "$repo" "$work/src" >/dev/null 2>&1; then
        rm -rf "$target"
        mkdir -p "$target"
        if [[ -d "$work/src/$path" ]]; then
          cp -R "$work/src/$path"/. "$target"/
        elif [[ -f "$work/src/$path" ]]; then
          cp "$work/src/$path" "$target/SKILL.md"
        else
          warn "legacy skill path missing: $name ($path)"
          rm -rf "$work"
          continue
        fi
        ok "legacy skill: $name"
      else
        warn "legacy skill clone failed: $name ($repo)"
      fi
      rm -rf "$work"
    done <<< "$legacy_skills"
  fi

  # GSD-classic via npm (separate path). Keep project/local installs from writing
  # global npm state unless the user installs GSD separately.
  if [[ "$SKIP_GSD" == "1" ]]; then
    info "Skipping GSD install (per --skip-gsd)"
    return 0
  fi
  if [[ "$INSTALL_SCOPE" != "user" ]]; then
    warn "Skipping global GSD npm install for $SCOPE_LABEL scope"
    warn "Install GSD globally later if needed: npm install -g get-shit-done-cc"
    return 0
  fi

  if command -v npm >/dev/null 2>&1; then
    if ! command -v get-shit-done-cc >/dev/null 2>&1; then
      if npm install -g get-shit-done-cc >/dev/null 2>&1; then
        ok "GSD installed via npm"
      else
        warn "GSD install failed (npm install -g get-shit-done-cc)"
      fi
    else
      info "GSD already installed"
    fi
  else
    warn "npm not in PATH — cannot install GSD. Run later: npm install -g get-shit-done-cc"
  fi
}

# ─── write marker ──────────────────────────────────────────────────────
write_marker() {
  step "Writing install marker"
  [[ "$DRY_RUN" == "1" ]] && { info "(dry-run) skipping marker"; return 0; }
  local sha=""
  if [[ -d "$TMP_WORK/src/.git" ]]; then
    sha="$(git -C "$TMP_WORK/src" rev-parse HEAD)"
  fi
  jq -n \
    --arg version "$SCRIPT_VERSION" \
    --arg sha "$sha" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg kind "$INSTALL_KIND" \
    --arg backup "$BACKUP_DIR" \
    --arg scope "$INSTALL_SCOPE" \
    --arg target "$CLAUDE_DIR" \
    '{version:$version, git_sha:$sha, installed_at:$ts, install_kind:$kind, install_scope:$scope, target_dir:$target, last_backup:$backup}' \
    > "$MARKER_FILE"
  chmod 644 "$MARKER_FILE"
  ok "Marker: $MARKER_FILE"
}

# ─── done banner ───────────────────────────────────────────────────────
print_done() {
  step "Install complete"
  if [[ "$DRY_RUN" == "1" ]]; then
    cat <<EOF

${C_GRN}AA Dev Stack v${SCRIPT_VERSION}${C_RST} dry run complete (scope: ${SCOPE_LABEL}).

No files were modified.

Target preview:
  Scope:     $SCOPE_LABEL
  Target:    $CLAUDE_DIR
  Commands:  $CLAUDE_DIR/commands/
  Settings:  $CLAUDE_DIR/settings.json
  CLAUDE.md: $CLAUDE_DIR/CLAUDE.md
  Secrets:   $CLAUDE_DIR/secrets/
  Hooks state: $CLAUDE_DIR/aa-hooks.json

EOF
    return 0
  fi

  cat <<EOF

${C_GRN}AA Dev Stack v${SCRIPT_VERSION}${C_RST} installed (${INSTALL_KIND}, scope: ${SCOPE_LABEL}).

Next steps:
  1. Open a NEW Claude Code session (so hooks/skills reload)
  2. Run:  ${C_BLU}/aa-hooks${C_RST}     to see all 7 hooks
  3. Run:  ${C_BLU}/aa-connect agent-architects${C_RST}  to wire up AA MCP

Files:
  Scope:     $SCOPE_LABEL
  Target:    $CLAUDE_DIR
  Commands:  $CLAUDE_DIR/commands/
  Settings:  $CLAUDE_DIR/settings.json    (merged, not overwritten)
  CLAUDE.md: $CLAUDE_DIR/CLAUDE.md        (managed block between markers)
  Secrets:   $CLAUDE_DIR/secrets/         (700; files 600)
  Hooks state: $CLAUDE_DIR/aa-hooks.json
  Backups:   $BACKUP_DIR

Smoke test:
  bash $TMP_WORK/src/test/smoke-test.sh

EOF
}

# ─── main ──────────────────────────────────────────────────────────────
main() {
  printf '%s━━━ AA Dev Stack installer v%s ━━━%s\n' "$C_BLU" "$SCRIPT_VERSION" "$C_RST"
  [[ "$DRY_RUN" == "1" ]] && warn "DRY-RUN MODE — no files will be modified"

  preflight
  fetch_source
  detect_install_kind
  backup_existing
  install_claudemd
  install_settings
  install_hook_scripts
  install_hook_settings
  install_secrets_dir
  install_aa_hooks_state
  install_short_name_commands
  install_seed_memory
  install_community_skills
  write_marker
  print_done
}

main "$@"
