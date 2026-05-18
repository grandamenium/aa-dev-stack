---
description: Toggle AA hooks on/off (enable|disable|list|on|off)
allowed-tools: Bash(cat:*), Bash(jq:*), Bash(mkdir:*), Bash(mv:*), Bash(printf:*), Bash(test:*), Write
argument-hint: "[enable|disable|list|on|off] [hook-name]"
---

## Available hooks
secret-scan, dangerous-bash-firewall, git-push-guard, auto-format, typecheck-on-stop, test-affected-on-stop, session-start-context

## Default state
All hooks ENABLED by default EXCEPT `test-affected-on-stop` which is DISABLED by default (opt-in: it can be slow on cold projects).

## Args
$ARGUMENTS

## Your task

Parse $ARGUMENTS:

- empty or `list` → read global `~/.claude/aa-hooks.json` and project-local `.aa-hooks.json` with Bash, then print a status table showing each hook and whether it is currently enabled. Project-local settings override global settings.
- `enable <name>` → write `hooks.<name>.enabled = true` to project-local `.aa-hooks.json`, then confirm
- `disable <name>` → write `hooks.<name>.enabled = false` to project-local `.aa-hooks.json`, then confirm
- `on` → enable all 7 hooks
- `off` → disable all 7 hooks
- bad input → show usage:

```
Usage: /aa-hooks [enable|disable|list|on|off] [hook-name]

Examples:
  /aa-hooks                          show current state
  /aa-hooks list                     same
  /aa-hooks disable auto-format      turn off auto-format for this session
  /aa-hooks enable test-affected-on-stop
  /aa-hooks off                      kill all (use sparingly)
  /aa-hooks on                       restore all defaults
```

## State file shape

Global state lives at `~/.claude/aa-hooks.json`; project overrides live at `.aa-hooks.json`. The hook scripts read project overrides on every fire before falling back to global state, so project changes do not need a restart:

```json
{
  "version": 1,
  "hooks": {
    "secret-scan":           {"enabled": true},
    "dangerous-bash-firewall": {"enabled": true},
    "git-push-guard":        {"enabled": true},
    "auto-format":           {"enabled": true},
    "typecheck-on-stop":     {"enabled": true},
    "test-affected-on-stop": {"enabled": false},
    "session-start-context": {"enabled": true}
  }
}
```

When writing project-local `.aa-hooks.json`, preserve the version field and any unknown hook keys (forward compatibility).

Use `$HOME/.claude/aa-hooks.json` instead of a literal `~` path when reading global state. Use `.aa-hooks.json` when writing project overrides. If a file does not exist, treat it as `{"version":1,"hooks":{}}`.

Use Bash for reads. Use Bash or Write for project-local `.aa-hooks.json` writes only. Do not use Read. Do not use Python. Do not use absolute paths like `/Users/.../.claude/aa-hooks.json`.

For writes, run small separate Bash commands rather than one chained command:

1. If the project file is missing: `printf '%s\n' '{"version":1,"hooks":{}}' > .aa-hooks.json`
2. For `enable <name>`:
   `jq --arg hook "<name>" '.version = (.version // 1) | .hooks = (.hooks // {}) | .hooks[$hook] = ((.hooks[$hook] // {}) + {"enabled": true})' .aa-hooks.json > .aa-hooks.json.tmp`
3. For `disable <name>`:
   `jq --arg hook "<name>" '.version = (.version // 1) | .hooks = (.hooks // {}) | .hooks[$hook] = ((.hooks[$hook] // {}) + {"enabled": false})' .aa-hooks.json > .aa-hooks.json.tmp`
4. `mv .aa-hooks.json.tmp .aa-hooks.json`
