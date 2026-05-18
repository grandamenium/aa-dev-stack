---
description: Toggle AA hooks on/off (enable|disable|list|on|off)
allowed-tools: Bash(cat:*), Bash(jq:*), Bash(mkdir:*), Write
argument-hint: "[enable|disable|list|on|off] [hook-name]"
disable-model-invocation: true
---

## Current state
!`cat ~/.claude/aa-hooks.json 2>/dev/null || echo '{"version":1,"hooks":{}}'`

## Available hooks
secret-scan, dangerous-bash-firewall, git-push-guard, auto-format, typecheck-on-stop, test-affected-on-stop, session-start-context

## Default state
All hooks ENABLED by default EXCEPT `test-affected-on-stop` which is DISABLED by default (opt-in: it can be slow on cold projects).

## Args
$ARGUMENTS

## Your task

Parse $ARGUMENTS:

- empty or `list` → print a status table showing each hook and whether it's currently enabled (read from the state above)
- `enable <name>` → set `hooks.<name>.enabled = true` in `~/.claude/aa-hooks.json`, write the file, confirm
- `disable <name>` → set `hooks.<name>.enabled = false`, write the file, confirm
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

`~/.claude/aa-hooks.json` (the hook scripts read this on every fire — no restart needed):

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

When writing, preserve the version field and any unknown hook keys (forward compatibility).

Make sure `~/.claude/` exists (`mkdir -p`) before writing.
