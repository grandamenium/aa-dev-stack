---
allowed-tools: Bash(git:*), Bash(npm test:*), Bash(pytest:*), Bash(cargo test:*), Bash(go test:*), Bash(gh pr create:*)
description: End-of-task discipline — merge, PR, keep, or discard
disable-model-invocation: true
---

## Context
- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Ahead/behind main: !`git rev-list --left-right --count main...HEAD 2>/dev/null || git rev-list --left-right --count master...HEAD 2>/dev/null`
- GIT_DIR == GIT_COMMON: !`[ "$(cd "$(git rev-parse --git-dir)" && pwd -P)" = "$(cd "$(git rev-parse --git-common-dir)" && pwd -P)" ] && echo "normal repo" || echo "worktree"`
- Recent commits: !`git log --oneline -5`

## Your task

**Step 1 — Verify tests pass.** Detect framework (package.json scripts, Cargo.toml, pyproject.toml, go.mod) and run the test command. If tests fail, STOP and report. Do not proceed.

**Step 2 — Present 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to main locally
2. Push and create a Pull Request
3. Keep the branch as-is
4. Discard this work

Which option?
```

(If detached HEAD, show only 3 options — drop the merge option.)

**Step 3 — Execute the chosen option:**

- **1 (merge):** cd to main repo root, checkout main, pull, merge feature branch, re-run tests, then `git branch -d` the feature branch. If this is a worktree under `.worktrees/`, also `git worktree remove` it after the merge succeeds.
- **2 (PR):** `git push -u origin <branch>`, then `gh pr create` with Summary + Test Plan. DO NOT clean up worktree (user needs it for iteration).
- **3 (keep):** Report branch + worktree path. Do nothing else.
- **4 (discard):** Require user to type "discard" exactly. Then force-delete branch with `git branch -D` and remove worktree if applicable.

**Critical rules:**
- Never `git worktree remove` from inside the worktree being removed — always cd to main root first
- Never delete worktrees you didn't create (only cleanup paths under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/`)
- Never proceed past Step 1 with failing tests
- Always run `git worktree prune` after removing a worktree (self-healing)
