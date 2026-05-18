---
description: Bootstrap a new project with AA conventions
allowed-tools: Bash(mkdir:*), Bash(git init:*), Bash(npx create-next-app:*), Bash(uv init:*), Bash(deno init:*), Write, Read
argument-hint: "[project-name] [--stack=next|python|node|deno]"
disable-model-invocation: true
---

## Args
Project name and optional stack flag: $ARGUMENTS

## Existing baseline
- Global CLAUDE.md: @~/.claude/CLAUDE.md (if missing, baseline not installed yet)

## Your task

Parse $ARGUMENTS for project name and `--stack` flag. Use approval-friendly, single-purpose tool calls. Do not run compound shell commands with `&&`, `;`, pipes, command substitution, shell variables, redirects, or `cd`.

1. **Create directory** named after the first positional arg
   - If directory already exists → STOP, refuse rather than clobber
   - Run exactly one directory command: `mkdir <name>`
   - Run exactly one git command: `git init <name>`

2. **Drop project CLAUDE.md** (short, < 60 lines)
   - Reference the global baseline at `~/.claude/CLAUDE.md`
   - Add project-specific sections: Stack, Architecture, Verification path
   - Leave placeholders for stack-specific notes

3. **Do not create project `.claude/` files by default**
   - Claude Code treats project `.claude/` settings, commands, skills, and agents as sensitive paths.
   - In default/noninteractive runs, do not create or write under `<name>/.claude/`.
   - Instead, note in the success message that project `.claude/` files are an optional interactive follow-up.
   - If the user explicitly passed `--with-claude-dir`, explain that Claude will ask for permission and then stop; do not attempt the sensitive writes in this command.

4. **Scaffold stack if --stack flag present:**
   - `--stack=next`: `npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --no-import-alias --use-npm --yes`
   - `--stack=python`: `uv init --lib --python 3.13` (or `pip` fallback)
   - `--stack=node`: minimal Node 22 ESM with tsx + tsc + biome by writing these files directly:
     - `package.json`
     - `tsconfig.json`
     - `src/index.ts`
     - `README.md`
   - `--stack=deno`: `deno init`
   - No flag: just the AA shell

5. **Register with claude-projects** (if `ccode` CLI is present):
   - Skip this step in noninteractive mode unless the user explicitly asks for registration.

6. **Report success** with the project path and next steps:
   - "Project ready at <path>"
   - "Open with: `cd <path> && claude`"
   - "Next: edit CLAUDE.md with project-specific notes"
   - "Optional: create project `.claude/` settings/commands/skills interactively if you want committed project-local Claude config"

Do not probe for `node`, `npm`, or `ccode` availability. Do not install npm dependencies for the minimal `--stack=node` scaffold; leave `npm install` as a next step.
