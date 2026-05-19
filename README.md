# AA Dev Stack

The opinionated agentic dev stack for Agent Architects members.

One install. Loaded Claude Code: baseline operating constitution, 7 safety hooks, 9 slash commands, first-party AA skills, community-bundled skills, and the AA MCP for community-aware AI.

## Install

```bash
claude plugin marketplace add github:grandamenium/aa-marketplace
claude plugin install aa-dev-stack
curl -fsSL https://raw.githubusercontent.com/grandamenium/aa-dev-stack/main/installer/install.sh | bash
```

The plugin install gives you commands, hooks, and first-party skills. The installer script does the extra work the plugin system doesn't: merges the baseline CLAUDE.md, copies commands for short names, creates the secrets directory, and bundles ten community skills.

## What you get

### Baseline CLAUDE.md
A 111-line operating constitution. State assumptions or halt. Verify before claiming. Surgical edits. Git protocol with no force-pushing, no commits to main, no `git add -A`. See [baseline-claude-md.md](baseline-claude-md.md).

### Slash commands

| Command | What it does |
|---|---|
| `/commit` | Conventional commit message from current diff |
| `/pr` | Open PR with auto-generated description |
| `/worktree` | Worktree create / list / remove |
| `/finish` | End-of-task router: merge / PR / squash / stash |
| `/cleanup` | Prune gone branches and stale worktrees |
| `/aa-init <name>` | Bootstrap a new project with AA conventions |
| `/aa-connect <service>` | Lazy on-demand setup for Supabase, Railway, Sentry, PostHog, Apify, Resend, AA MCP |
| `/aa-hooks [...]` | Toggle hooks on/off per session |
| `/aa` | Spine selector: small (GSD) vs large (m2c1) project routing |

### Hooks (7 default)

| Hook | Event | What it blocks/does |
|---|---|---|
| secret-scan | PreToolUse | Blocks writes containing API key patterns |
| dangerous-bash-firewall | PreToolUse | Blocks `rm -rf /`, force-push to main, etc. |
| git-push-guard | PreToolUse | Blocks `git push` without explicit approval |
| auto-format | PostToolUse | Runs biome / prettier on write |
| typecheck-on-stop | Stop | `tsc --noEmit` before declaring done (20s timeout) |
| test-affected-on-stop | Stop | Runs affected tests (default DISABLED, 20s timeout) |
| session-start-context | SessionStart | Injects recent git log, HANDOFF.md, PROGRESS.md |

Toggle any via `/aa-hooks disable <name>`.

### First-party AA skills

Shipped directly with this plugin:

| Skill | What it does |
|---|---|
| `should-compact` | Decides whether the current session should compact or continue |
| `skill-promoter` | Finds repeatable workflows that deserve promotion into reusable skills, then routes approved creation through `skill-creator` when available |
| `skill-optimizer` | Improves existing skills from transcript/log evidence rather than vibe-based rewrites |
| `context-audit` | Read-only audit of context loading, project memory, skills, hooks, MCP, and orchestration footprint |

`skill-creator` remains the creation path when a new skill is approved. `skill-promoter` identifies and scopes candidates; `skill-creator` performs the actual scaffold/create workflow where installed.

### Bundled community skills

Installed automatically by `installer.sh`:

- frontend-design + claude-api (Anthropic)
- supabase + postgres-best-practices (Supabase)
- taste-skill (Leonxlnx)
- handoff (thepushkarp)
- claude-memory-skill (hanfang)
- dream-skill, local-ultrareview, m2c1 (James / Agent Architects)
- GSD-classic (small-project methodology, installed via npm)

### MCP servers

- `agent-architects` — read-only community access (courses, posts, members)
- `sentry` — OAuth via official `mcp.sentry.dev`
- Others (supabase, railway, posthog, apify, resend) — configured on demand via `/aa-connect <service>`

## Smoke test

```bash
bash test/smoke-test.sh
```

Runs the critical-path install checks plus V2 first-party skill checks. Reports pass/fail with concrete next steps.

## Uninstall / reset

```bash
bash test/smoke-cleanup.sh
```

Restores backups, removes the plugin, strips merged settings.

## What's deferred to v1.1

`/promote-memory`, `/project-review`, 4 AA MCP companion skills, 25-test smoke, GH Actions CI. See [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).

## Source of truth

Built per [CANONICAL-IMPLEMENTATION.md](https://github.com/grandamenium/aa-dev-stack/blob/main/CANONICAL-IMPLEMENTATION.md) in the source repo.

Issues and discussion: [github.com/grandamenium/aa-dev-stack/issues](https://github.com/grandamenium/aa-dev-stack/issues)
