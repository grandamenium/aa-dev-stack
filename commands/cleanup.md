---
allowed-tools: Bash(git fetch:*), Bash(git branch:*), Bash(git worktree:*), Bash(git rev-parse:*), Bash(git log:*), Bash(awk:*), Bash(grep:*), Bash(sed:*), Bash(du:*)
description: Prune gone branches and stale worktrees
disable-model-invocation: true
---

## Context
- Fetching with prune: !`git fetch --prune 2>&1`
- Local branches with status: !`git branch -v`
- Worktrees: !`git worktree list`

## Your task

1. Identify branches marked [gone] in the output above
2. For each [gone] branch:
   - Check if it has unpushed commits (`git log <branch> --not --remotes`)
   - If yes → ASK before deleting (read this carefully back to user)
   - If no → safe to delete
3. For branches confirmed safe (or approved), use this bash to clean up worktrees + branches:

```bash
git branch -v | grep '\[gone\]' | sed 's/^[+* ]//' | awk '{print $1}' | while read branch; do
  worktree=$(git worktree list | grep "\\[$branch\\]" | awk '{print $1}')
  if [ ! -z "$worktree" ] && [ "$worktree" != "$(git rev-parse --show-toplevel)" ]; then
    git worktree remove --force "$worktree"
  fi
  git branch -D "$branch"
done
git worktree prune
```

4. Report: how many branches deleted, how many worktrees removed, disk space freed (use `du -sh` on removed paths before deletion if practical).

If no [gone] branches → report "nothing to clean up" and stop.
