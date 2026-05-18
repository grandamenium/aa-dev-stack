---
allowed-tools: Bash(git checkout:*), Bash(git checkout -b:*), Bash(git add:*), Bash(git status:*), Bash(git push:*), Bash(git commit:*), Bash(gh pr create:*), Bash(git log:*), Bash(git diff:*)
description: Commit, push, and open a PR
disable-model-invocation: true
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Commits since main: !`git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline 2>/dev/null || echo "(no base diff)"`

## Your task

Based on the above changes:

1. Create a new branch if on main/master (name from change summary, e.g. feat/add-auth)
2. Create a single commit with a Conventional Commits message
3. Push the branch to origin with -u
4. Create a PR via `gh pr create` with:
   - Title under 70 chars
   - Body containing `## Summary` (2-3 bullets) and `## Test Plan` (checklist)
5. Print the PR URL on success

You have the capability to call multiple tools in a single response. You MUST do all of the above in a single message. Do not use any other tools or do anything else. Do not send any other text or messages besides these tool calls.
