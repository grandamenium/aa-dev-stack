---
description: Bootstrap a new project with AA conventions
allowed-tools: Bash(mkdir:*), Bash(git init:*), Bash(cd:*), Bash(npx create-next-app:*), Bash(uv init:*), Bash(deno init:*), Bash(npm init:*), Write, Read
argument-hint: "[project-name] [--stack=next|python|node|deno]"
disable-model-invocation: true
---

## Args
Project name and optional stack flag: $ARGUMENTS

## Existing baseline
- Global CLAUDE.md: @~/.claude/CLAUDE.md (if missing, baseline not installed yet)

## Your task

Parse $ARGUMENTS for project name and `--stack` flag.

1. **Create directory** named after the first positional arg
   - If directory already exists → STOP, refuse rather than clobber
   - `mkdir <name> && cd <name> && git init`

2. **Drop project CLAUDE.md** (short, < 60 lines)
   - Reference the global baseline at `~/.claude/CLAUDE.md`
   - Add project-specific sections: Stack, Architecture, Verification path
   - Leave placeholders for stack-specific notes

3. **Create `.claude/` subdir structure**
   - `.claude/settings.json` (empty `{}` for now, project commits this)
   - `.claude/settings.local.json` (empty `{}`, gitignored)
   - `.claude/aa-hooks.json` with `{"hooks": {}}` (project-level hook overrides go here)
   - `.claude/commands/.gitkeep`, `.claude/skills/.gitkeep`, `.claude/agents/.gitkeep`

4. **Scaffold stack if --stack flag present:**
   - `--stack=next`: `npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --no-import-alias --use-npm --yes`
   - `--stack=python`: `uv init --lib --python 3.13` (or `pip` fallback)
   - `--stack=node`: minimal Node 22 ESM with tsx + tsc + biome
   - `--stack=deno`: `deno init`
   - No flag: just the AA shell

5. **Register with claude-projects** (if `ccode` CLI is present):
   - `ccode add <name> -d "<short description>"`
   - If `ccode` missing, skip silently

6. **Report success** with the project path and next steps:
   - "Project ready at <path>"
   - "Open with: `cd <path> && claude`"
   - "Next: edit CLAUDE.md with project-specific notes"

Do all of the above in a single message where possible.
