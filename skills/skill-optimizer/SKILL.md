---
name: skill-optimizer
description: Improve existing skills using real transcript or tool-use evidence. Use when a user asks to optimize, tune, audit, or improve a skill based on how agents actually used it.
when_to_use: |
  Trigger phrases: "optimize this skill", "improve this skill from transcripts",
  "why did this skill misfire", "skill over-triggered", "skill under-triggered",
  "tune skill instructions", "evaluate skill usage".
  Do NOT trigger for opinion-only rewrites when no transcript/log evidence is available.
allowed-tools: Read Grep Glob Bash(git diff *) Bash(git status *) Bash(find *) Bash(rg *)
---

# Skill Optimizer

Optimize skills from observed usage, not vibes. Every recommendation must cite
transcript, log, or tool-use evidence.

## Source Note

James has referenced an existing skill optimizer in a remote repository. Reuse that
implementation or design when it is supplied or discoverable. If you cannot find it,
state that clearly and proceed with this evidence-driven workflow rather than
inventing hidden behavior.

## Inputs To Locate

Find real usage examples before proposing edits:

- Claude JSONL transcripts.
- `.claude/projects/**`.
- Agent session logs.
- Tool-use traces.
- Skill attribution fields such as `attributionSkill`.
- Handoffs or retrospectives that mention skill failures.
- Before/after outputs from sessions that invoked the skill.

If no usage evidence exists, stop after a readiness report. Recommend collecting
examples instead of rewriting the skill.

## Evaluation Questions

For each skill invocation or missed invocation, ask:

- Did the skill trigger for the right task?
- Did it over-trigger on unrelated tasks?
- Did it under-trigger when it should have been used?
- Did the description/frontmatter make the trigger too broad or too narrow?
- Did instructions cause tool mistakes, unsafe writes, or missing verification?
- Were required files, references, assets, or scripts missing?
- Did the model ignore or misunderstand any section?
- Was the output format useful to the user?
- Did the skill bloat context without improving behavior?

## Scoring

Score the current skill from 0-5 for:

- Trigger precision.
- Trigger recall.
- Workflow clarity.
- Tool guidance.
- Safety/approval handling.
- Output usefulness.
- Maintainability/context size.

Include evidence for every score below 4.

## Diff Plan

Before editing, produce a concrete plan:

- Problem observed.
- Evidence path/transcript reference.
- Proposed edit.
- Expected behavior change.
- Risk of the edit.
- Whether the edit requires user approval.

Recommended edit categories:

- Trigger wording.
- Missing constraints.
- Workflow order.
- Required examples.
- Allowed tools.
- Reference docs to add or remove.
- Output format.
- Safety and approval gates.

## Edit Rules

- Apply changes only after user approval unless the user explicitly asked for automatic optimization.
- Preserve skill scope. Do not turn focused skills into generic mega-docs.
- Keep `SKILL.md` concise. Move long examples, rubrics, and transcript excerpts into `references/`.
- Do not delete historical evidence; summarize it or store it in a reference file.
- Run any available skill/plugin smoke tests after editing.

## Output

Return:

- Evidence summary.
- Current scorecard.
- Before/after diff plan.
- Applied changes, if approved.
- Tests run and results.
- Remaining risks and data gaps.

