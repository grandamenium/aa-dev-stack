---
allowed-tools: Bash(git worktree:*), Bash(git rev-parse:*), Bash(git branch:*), Bash(git check-ignore:*), Bash(basename:*), Bash(ls:*), Bash(cat:*), Bash(echo:*), Bash(npm install:*), Bash(pip install:*), Bash(poetry install:*), Bash(cargo build:*), Bash(uv sync:*)
description: Manage git worktrees (new/list/remove)
argument-hint: "[new|list|remove] [name]"
disable-model-invocation: true
---

## Context
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null`
- Existing worktrees: !`git worktree list 2>/dev/null`
- .worktrees in .gitignore?: !`git check-ignore -q .worktrees && echo "yes" || echo "no"`

## Args
$ARGUMENTS

## Your task
Parse $ARGUMENTS:

**new <name>** →
  1. Verify `.worktrees/` is gitignored (add to .gitignore + commit if not)
  2. Run `git worktree add .worktrees/<name> -b <name>`
  3. cd into it, run project setup (npm i / cargo build / pip install / poetry install / uv sync — auto-detect from package.json / Cargo.toml / requirements.txt / pyproject.toml)
  4. Report the worktree path

**list** → show the `git worktree list` output

**remove <name>** →
  1. Check if worktree has uncommitted changes (cd in, `git status --porcelain`)
  2. If dirty → STOP, ask for explicit confirmation
  3. cd back to main repo root (CRITICAL — never run `git worktree remove` from inside the target)
  4. Run `git worktree remove .worktrees/<name>`
  5. Run `git worktree prune`

bad input → print usage:
```
Usage: /worktree [new|list|remove] [name]
  new <name>     create a new worktree under .worktrees/<name>
  list           show current worktrees
  remove <name>  remove a worktree (must be clean)
```
