---
description: AA spine selector — routes to GSD (small) or m2c1 (large) based on project size
disable-model-invocation: true
---

## Your task

Ask the user:

```
How big is this build?

  small   — under 1 day, iterative, one or two domains
  medium  — multi-domain but you have clarity on what to build
  large   — autonomous build worth orchestrating end-to-end

Quick description?
```

Based on the answer:

- **small** → suggest:
  - `/aa-init <project-name>` if it's a new project
  - then `/new-project` (GSD) to start the discuss → plan → execute loop

- **medium** → ask 1-2 clarifying questions:
  - Are there real unknowns you need to discover?
  - Will it touch more than 3 files / domains?
  - Then route: high-unknown / multi-domain → m2c1; otherwise → GSD

- **large** → suggest invoking the m2c1 skill with a brain dump

Do NOT auto-execute the recommended next command. Recommend it, let the user run it.

This is glue — your job is mental routing, not automation. Keep responses under 6 lines.
