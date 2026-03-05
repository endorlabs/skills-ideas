---
name: endor-setup
description: |
  Onboarding wizard for Endor Labs. Guides users through prerequisites, MCP server configuration, authentication, namespace setup, and running their first scan.
  - MANDATORY TRIGGERS: endor setup, endor onboarding, endor configure, endor auth, endor install, setup endor
---

# Endor Labs Setup Wizard

Guide user from zero to scanning in 5 minutes. MCP server runs via `npx` (published `endorctl` npm package) -- no binary install required.

## Step 1: Check Prerequisites

Run these checks in order:

```bash
node --version   # Requires v18+
npx --version    # Bundled with Node.js; if missing: npm install -g npx
npx -y endorctl --version  # Downloads and runs endorctl (-y auto-confirms)
```

If Node.js missing, install:
```bash
# macOS
brew install node
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs
# nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && nvm install 20
```

## Step 2: Configure MCP Server

Check for `endor-cli-tools` in `.claude/settings.json`. If absent, create/update:

```json
{
  "mcpServers": {
    "endor-cli-tools": {
      "command": "npx",
      "args": ["-y", "endorctl", "ai-tools", "mcp-server"],
      "env": {
        "ENDOR_NAMESPACE": "your-namespace",
        "ENDOR_API": "https://api.endorlabs.com",
        "ENDOR_MCP_SERVER_AUTH_MODE": "google"
      }
    }
  }
}
```

**User must restart Claude Code after modifying settings.json.**

## Step 3: Authenticate

Ask the user which option they prefer:

### Option A: CLI Authentication (Recommended)

Opens browser for OAuth, caches credentials locally. Ask which provider:

| Provider | `--auth-mode` | Extra Flags |
|----------|---------------|-------------|
| Google | `google` | -- |
| GitHub | `github` | -- |
| GitLab | `gitlab` | -- |
| Enterprise SSO | `sso` | `--auth-tenant <tenant-name>` |
| Browser (generic) | `browser-auth` | -- |

Run with user's namespace (use `demo-trial` if unknown):
```bash
npx -y endorctl init --auth-mode <provider> -n <namespace>
```

Verify:
```bash
npx -y endorctl auth --print-access-token -n <namespace>
```
If a token prints, CLI auth works. Then set `ENDOR_MCP_SERVER_AUTH_MODE` in settings.json to match.

### Option B: MCP Server Auth Only

MCP server auto-opens browser on first tool call. Token cached 1 hour.

| Provider | `ENDOR_MCP_SERVER_AUTH_MODE` | Extra Env Vars |
|----------|-------------------------------|----------------|
| Google | `google` | -- |
| GitHub | `github` | -- |
| GitLab | `gitlab` | -- |
| Enterprise SSO | `sso` | `ENDOR_MCP_SERVER_AUTH_TENANT` |
| Email | `email` | `ENDOR_MCP_SERVER_AUTH_EMAIL` |

### Option C: API Key Auth (CI/CD / Headless)

Instruct user to set env vars themselves (never ask for credentials in chat):
```bash
export ENDOR_API_CREDENTIALS_KEY=<your-api-key>
export ENDOR_API_CREDENTIALS_SECRET=<your-api-secret>
```

Or add to settings.json `env` block. Alternative: `export ENDOR_TOKEN=<your-token>`.

For headless OAuth (no local browser):
```bash
npx -y endorctl init --auth-mode google --headless-mode -n <namespace>
```
Prints a URL to open on any device.

## Step 4: Configure Namespace

Ask for their Endor Labs org name (visible at top-left of [app.endorlabs.com](https://app.endorlabs.com)). Update `ENDOR_NAMESPACE` in settings.json.

If user did CLI auth (Option A), ensure same namespace in both CLI (`-n`) and settings.json. If placeholder was used, re-run: `npx -y endorctl init --auth-mode <provider> -n <actual-namespace>`.

Without namespace: `demo-trial` provides limited demo access. New users: sign up at [endorlabs.com](https://www.endorlabs.com) or run `/endor-demo`.

## Step 5: Verify Setup

For CLI auth users, verify token:
```bash
npx -y endorctl auth --print-access-token -n <namespace>
```

After restarting Claude Code, verify MCP by calling `check_dependency_for_vulnerabilities`:
- ecosystem: `npm`, dependency_name: `lodash`, version: `4.17.20`

If it returns vulnerability data, setup works. Browser auth prompt on first use is expected for Option B.

## Step 6: Success

```markdown
## Setup Complete!

### First Steps
1. `/endor-scan` - Scan current project
2. `/endor-check express 4.17.1` - Check a dependency
3. `/endor-help` - All commands

### Daily Workflow
- `/endor-scan` regularly during development
- `/endor-check` when adding dependencies
- `/endor-review` before creating PRs
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `node`/`npx` not found | Install Node.js v18+ |
| `endorctl` not found via npx | Check internet; run `npx -y endorctl --version` |
| MCP tools not showing | Restart Claude Code after editing settings.json |
| Browser auth not opening | Verify `--auth-mode` / `ENDOR_MCP_SERVER_AUTH_MODE` |
| `endorctl init` fails | Check internet and `--auth-mode`; try `browser-auth` fallback |
| Token expired | Re-run `endorctl init` |
| CLI works, MCP fails | Match `ENDOR_MCP_SERVER_AUTH_MODE` to `--auth-mode` used in init |
| `namespace not found` | Verify org name at app.endorlabs.com; sync CLI `-n` and settings.json |
| `permission denied` | Verify account access to namespace |
| Timeout on first run | First `npx` download takes 30-60s |
| Corporate proxy | Set `HTTPS_PROXY` in settings.json env block |
| Headless / no browser | Use `--headless-mode` or API key auth (Option C) |

## Available MCP Tools After Setup

| Tool | Description |
|------|-------------|
| `scan` | Scan repo for vulnerabilities, secrets, SAST |
| `check_dependency_for_vulnerabilities` | Check package version for CVEs |
| `get_endor_vulnerability` | Detailed CVE/GHSA info |
| `get_resource` | Retrieve any Endor Labs resource |
