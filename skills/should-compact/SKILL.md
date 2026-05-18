---
name: should-compact
description: Context budget discipline. Use when the session feels long, when context usage looks heavy (60%+ on the status bar), before starting a major new task in an already-loaded session, or when the user mentions compaction, context, handoff, or /compact. Runs a save-work-first checklist BEFORE compaction so the next session keeps the gains.
when_to_use: |
  Trigger phrases: "should I compact", "context is getting full", "this session is long",
  "before I /compact", "save my work first", "/should-compact", "handoff", "wrap this session".
  Do NOT trigger for routine "this is taking a while" comments unrelated to context load,
  for memory consolidation (use dream), or for end-of-day review (use evening-review).
allowed-tools: Read Write Bash(git status *) Bash(git diff *) Bash(git log *)
---

# Should Compact — Save Before You Compact

Auto-compact fires around 95% context full. That is too late. By 95%, the most useful
session content is already at risk of getting summarized into oblivion. Compact early at
60-70% with deliberate artifact-saving so the next session starts hot.

## The discipline (run this checklist)

### 1. Check what's actually in flight

```!
git status --short
git log --oneline -5
```

Anything uncommitted or untracked that represents real work? Decide: commit, stash, or
write to a scratch file before compacting.

### 2. Write HANDOFF.md

If the current session is mid-task, create or update `HANDOFF.md` at the project root with:

```markdown
# Handoff — <date>

## What I was doing
<one-sentence task>

## Where I left off
- Last file edited: <path>
- Last decision: <one sentence>
- Open question: <one sentence or "none">

## Next concrete step
<one sentence — what would I type into Claude next?>

## Files in active context
- <path> — <why>
- <path> — <why>
```

The next session loads this via `hooks/session-start-context.sh`. Keep it under 50 lines.

### 3. Save key artifacts to disk

For each load-bearing finding from this session:
- Research summary? Write to `_research/<topic>.md`
- Code spike? Commit on a branch named `spike/<topic>`
- Design decision? Append to `DECISIONS.md` (one section per decision)

Anything that lives only in conversation state will be lost or compressed.

### 4. Decide: compact, fresh session, or keep going

| Signal | Action |
|---|---|
| Context bar shows >=60% AND task is paused at a clean checkpoint | `/compact` now |
| Context bar shows >=60% AND mid-implementation | Finish current sub-task, save, THEN `/compact` |
| Context bar shows >=80% AND task is large | Don't compact - open fresh session with `HANDOFF.md` loaded |
| Context bar shows <50% | Don't compact yet, keep going |

### 5. Run `/compact` (only after the above)

The user runs this manually. This skill does NOT run `/compact` for them. Auto-compaction
strips skill content down to first 5,000 tokens per skill (25,000 combined budget across
all invoked skills) after the summary. Deliberate compaction lets the user choose what to
preserve in the summary prompt.

## Why this matters

Auto-compact at 95% fires under duress: model summarizes whatever happens to be in context,
prioritizes recency, drops the early research that set up the task. Manual compaction at
60-70% with a written HANDOFF.md lets the next session reload the exact state you cared
about.

## When NOT to use this skill

- Routine slow turns unrelated to context load - just wait
- Memory consolidation across sessions - that's `dream`
- End-of-day reflection - that's `evening-review`
- "Where am I?" with low context load - just look at `git status`
