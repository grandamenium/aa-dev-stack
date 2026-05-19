---
name: skill-promoter
description: Discover project-local skill candidates from repeated workflows, docs, transcripts, and code patterns. Use when a user asks what should become a skill, wants to promote recurring project knowledge into skills, or asks to mine a project for reusable agent procedures.
when_to_use: |
  Trigger phrases: "promote this to a skill", "what skills should this project have",
  "mine this repo for skills", "turn repeated workflows into skills",
  "create local project skills from our docs/transcripts".
  Do NOT trigger for writing one already-approved skill spec; use skill-creator directly.
allowed-tools: Read Grep Glob Bash(git status *) Bash(git ls-files *) Bash(find *) Bash(rg *)
---

# Skill Promoter

Discover candidate project skills before writing any of them. This skill is a
promotion scout, not a bulk skill generator.

## Default Stance

- Read broadly first.
- Propose an inventory before creating anything.
- Ask for approval before writing or modifying skill files.
- Prefer project-local skills for project-specific behavior.
- Route approved skill creation through the runtime `skill-creator` skill when available.

## Discovery Pass

Start with broad project exploration. Do not jump straight to authoring.

Inspect:

- `CLAUDE.md`, `AGENTS.md`, and variants.
- `.claude/**`, including commands, hooks, agents, settings, and project config.
- Existing `skills/**` or plugin skill directories.
- Rules, instruction files, handoffs, memory files, retrospectives, audit docs, runbooks.
- README, architecture docs, deployment docs, test docs, and operational notes.
- Conversation transcripts and logs if present:
  - `.claude/projects/**`
  - JSONL transcripts
  - agent logs
  - project-specific session records
- Actual code and tool patterns:
  - repeated scripts
  - repeated commands
  - recurring setup/debug/test workflows
  - project conventions that agents repeatedly rediscover

Use subagents for exploration when the runtime offers them and the user permits
parallel/delegated work. Assign them bounded read-only questions such as docs,
transcripts, and code-pattern discovery.

## Evidence Rules

Every proposed skill needs concrete evidence:

- File paths, transcript snippets, repeated commands, or multiple docs saying the same thing.
- Why a model would benefit from loading it just-in-time.
- Why it should be a skill instead of a README section, script, checklist, or comment.
- Staleness/risk notes when source docs conflict or look outdated.

Do not promote stale docs blindly. Flag them.

## Proposed Inventory Format

Return a table or bullets with:

- Skill name.
- Trigger/use case.
- Evidence from project.
- Why this belongs in a skill.
- Why this should not stay only as docs/code.
- Proposed location.
- Priority: high, medium, low.
- Risk: low, medium, high.
- Approval needed before write: yes/no.

Also include:

- `Do not promote`: items that should stay as docs, code, scripts, or one-off notes.
- `Open questions`: decisions the user must make before any skill is written.
- `Suggested first batch`: the smallest coherent set to create first.

## Creation Flow

After the user approves selected skills:

1. Detect whether the runtime already has a `skill-creator` skill.
2. If available, invoke or follow `skill-creator` to generate the approved skills.
3. If unavailable, tell the user how to install or enable the official skill creator.
4. Only fall back to a local compatible skill scaffold if licensing/source allows and the user approves.

Do not duplicate the official skill creator under another name unless there is no other
supported path and the user explicitly approves the fallback.

## Safety

- Do not silently create many skills.
- Do not overwrite existing skills without a diff and approval.
- Keep new skills concise; move long examples and references into `references/`.
- Preserve the original evidence list so future optimization can trace why the skill exists.
