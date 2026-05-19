---
name: context-audit
description: Read-only audit of a project agent environment for context bloat, stale or contradictory instructions, duplicated skills, broken tools, and confusing always-loaded context.
when_to_use: |
  Trigger phrases: "audit project context", "context bloat", "Claude is confused",
  "too much CLAUDE.md", "clean up agent instructions", "audit skills/tools/rules",
  "what context should be moved into skills".
  Default to read-only. Do not delete or rewrite context unless explicitly approved.
allowed-tools: Read Grep Glob Bash(wc *) Bash(find *) Bash(rg *) Bash(git status *) Bash(git ls-files *)
---

# Context Audit

Audit the local project agent environment for bloat, stale context, contradictory
rules, and tool/skill sprawl. Default to read-only.

## Audit Scope

Inspect:

- `CLAUDE.md`, `AGENTS.md`, and variants.
- `.claude/**`, including settings, commands, hooks, agents, MCP config, and skills.
- Plugin config and manifests.
- Project rules and instruction files.
- Memory files, handoffs, retrospectives, and progress logs.
- Automatically loaded docs.
- Orchestration frameworks such as GSD and m2c1.
- Local scripts and runbooks that agents are expected to follow.

## Checks

### Size And Load Risk

- `CLAUDE.md` should ideally be below 200 lines. Flag anything above 200 lines.
- Identify files that are always loaded or likely injected at session start.
- Identify large memories/handoffs that should become targeted references.

### Contradictions And Staleness

- Conflicting instructions across global, org, project, and local files.
- Old decisions that contradict current docs.
- Stale install/setup notes.
- Deprecated commands, MCP servers, or scripts.

### Tool And Skill Sprawl

- Unused or broken MCP servers.
- Too many always-on tools or hooks.
- Duplicated skill content.
- Skills with overlapping triggers.
- Skills that should be references, scripts, or docs instead.

### Agent Confusion Risks

- Multiple orchestration frameworks competing for the same task.
- Rules that encourage premature planning, over-delegation, or unsafe writes.
- Memory loaded too broadly.
- Project rules that conflict with user/org/global rules.

## Output Format

Return:

1. Executive summary.
2. Context map:
   - always-loaded
   - on-demand
   - stale/unclear
   - valuable keepers
3. Highest-risk bloat/confusion findings.
4. Recommended prune/split plan.
5. Safe edits that can be made automatically.
6. Edits requiring user approval.
7. Keep list for context that is valuable and should not be removed.
8. Candidate skills or references that should be created from current context.

## Safe Defaults

- Read-only unless explicitly approved.
- Prefer small reversible edits.
- Never delete memory, handoffs, rules, or skills without approval.
- If the user asks for automatic cleanup, first provide a diff plan and ask whether to apply it.

## CLAUDE.md Line Check

Always report the line count of `CLAUDE.md` when present:

```!
wc -l CLAUDE.md
```

Flag as:

- OK: under 150 lines.
- Watch: 150-200 lines.
- High risk: over 200 lines.

