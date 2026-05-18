# Changelog

## v0.1.0 — initial release

The opinionated agentic dev stack for Agent Architects members.

### What's in v1

- **Baseline CLAUDE.md** — 111-line operating constitution installed to `~/.claude/CLAUDE.md`
- **7 hooks** — secret-scan, dangerous-bash-firewall, git-push-guard, auto-format, typecheck-on-stop, test-affected-on-stop (default disabled), session-start-context. All Stop hooks timeout at 20s.
- **9 slash commands** — `/commit`, `/pr`, `/worktree`, `/finish`, `/cleanup`, `/aa-init`, `/aa-connect`, `/aa-hooks`, `/aa`
- **1 skill** — `should-compact`
- **10 community skills bundled** — installer auto-installs frontend-design, claude-api, supabase, postgres-best-practices, taste-skill, handoff, claude-memory-skill, dream-skill, local-ultrareview, m2c1
- **GSD-classic installed** — small-project methodology spine
- **MCP configs** — agent-architects (read-only community), sentry (OAuth via mcp.sentry.dev). Others (supabase, railway, posthog, apify, resend) onboarded lazily via `/aa-connect`.
- **Hook toggle command** — `/aa-hooks enable|disable|on|off|list`
- **Installer** — handles CLAUDE.md merge, settings deep-merge, secrets dir, short-name command copy, community skills install, idempotency

### Deferred to v1.1 (next week)

- `/promote-memory` command (cross-project flywheel)
- `/project-review` command (Friday routine)
- 4 AA MCP companion skills (aa-lesson-context, aa-find-help, aa-network, aa-member-lookup)
- 25-test smoke suite
- GitHub Actions CI matrix
- Track 2 Module 8 recording (depends on cut commands)

### Known limitations

- No Windows support (macOS + Linux only)
- Hooks may add measurable latency on cold projects; disable via `/aa-hooks` if needed
- AA MCP shared key rotation requires manual member action
