---
description: Connect a service (supabase|railway|sentry|posthog|apify|resend|agent-architects)
allowed-tools: Bash(mkdir:*), Bash(chmod:*), Bash(curl:*), Write, Read, Edit, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot
argument-hint: "<service>"
disable-model-invocation: true
---

## Args
Service to connect: $1

## Your task

Match $1 against the supported services. For an unknown service, print this list and stop:

```
supabase           Supabase auth + database (project URL + service key)
railway            Railway deployments (account API token)
sentry             Sentry errors (OAuth via mcp.sentry.dev, no manual key)
posthog            PostHog analytics (US/EU cloud, project + personal keys)
apify              Apify scraping (API token)
resend             Resend transactional email (API key)
agent-architects   AA community MCP (shared community key from pinned Skool post)
```

For the matched service:

1. **Open the API-key page** in Playwright if MCP is available, otherwise instruct the user with the URL:

   | Service | URL |
   |---|---|
   | supabase | https://supabase.com/dashboard |
   | railway | https://railway.com/account/tokens |
   | sentry | https://mcp.sentry.dev/mcp (OAuth — Claude Code triggers OAuth automatically; no manual capture) |
   | posthog | https://app.posthog.com/me/settings (also ask: US or EU cloud?) |
   | apify | https://console.apify.com/settings/integrations |
   | resend | https://resend.com/api-keys |
   | agent-architects | The pinned community post in Skool (link members to it) |

2. **Ask the user to paste the key directly in chat.** DO NOT use `browser_evaluate` to scrape the field — that would leak the key into the tool-call transcript. For Sentry: do NOT capture a token; verify the OAuth flow worked instead.

3. **Verify the key works BEFORE writing it to disk:**
   - supabase: `GET /rest/v1/` with `apikey` header
   - railway: GraphQL `query { me { email } }` against `backboard.railway.com`
   - sentry: query the MCP via `tools/list`
   - posthog: capture endpoint `POST /i/v0/e/` (no-op event)
   - apify: `GET /v2/users/me`
   - resend: `GET /domains`
   - agent-architects: JSON-RPC `tools/list` against the MCP

4. **Write to `~/.claude/secrets/<service>.env`** with mode 600. Directory `~/.claude/secrets/` must be 700.

   Format:
   ```
   <SERVICE>_API_KEY=...
   <SERVICE>_URL=...   (if applicable)
   ```

5. **Update `~/.claude/settings.json`** via `Edit` (not `Write` — never clobber):
   - Replace the `_placeholder` for `mcpServers.<service>` with real config
   - Use `envFile` pointing to the .env file (lets keys resolve at MCP startup)

6. **Run a final test query** to confirm the MCP is registered + reachable.

7. **Report success** with one line on what was configured and where the key lives (without printing the key).

## Security rules

- NEVER print the key in console output. Show only its prefix or length.
- NEVER use `browser_evaluate` against the password field.
- ALWAYS chmod the secrets dir to 700 and the .env file to 600.
- If the test query fails BEFORE you write to disk, fail loud and do not persist bad creds.
- For Sentry: OAuth handoff is preferred. If user wants manual token (for SDK use like sourcemaps), capture from https://sentry.io/settings/auth-tokens/ separately.
