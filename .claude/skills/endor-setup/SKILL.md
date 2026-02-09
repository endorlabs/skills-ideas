---
name: endor-setup
description: |
  Onboarding wizard for Endor Labs. Guides users through prerequisites, MCP server configuration, authentication, namespace setup, and running their first scan.
  - MANDATORY TRIGGERS: endor setup, endor onboarding, endor configure, endor auth, endor install, setup endor
---

# Endor Labs Setup Wizard

Guide the user from zero to scanning in 5 minutes. The MCP server runs via `npx` using the published `endorctl` npm package - no binary installation required.

## Step 1: Check Prerequisites

### 1.1 Check if Node.js is installed

Node.js v18+ is required to run the MCP server via `npx`.

```bash
node --version
```

If not installed, provide installation instructions:

```bash
# macOS (Homebrew)
brew install node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Or use nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
nvm install 20
```

### 1.2 Verify npx is available

```bash
npx --version
```

npx comes bundled with Node.js. If missing, run `npm install -g npx`.

### 1.3 Quick test of endorctl via npx

```bash
npx -y endorctl --version
```

This downloads and runs endorctl without installing it globally. The `-y` flag auto-confirms the download.

## Step 2: Configure the MCP Server

### 2.1 Check if MCP server is already configured

Look for `endor-cli-tools` in the project's `.claude/settings.json`.

### 2.2 If not configured, create the settings

Create or update `.claude/settings.json` in the project root:

```json
{
  "mcpServers": {
    "endor-cli-tools": {
      "command": "npx",
      "args": [
        "-y",
        "endorctl",
        "ai-tools",
        "mcp-server"
      ],
      "env": {
        "ENDOR_NAMESPACE": "your-namespace",
        "ENDOR_API": "https://api.endorlabs.com",
        "ENDOR_MCP_SERVER_AUTH_MODE": "google"
      }
    }
  }
}
```

### 2.3 Important: Restart Required

Tell the user: **You must restart Claude Code after creating or modifying settings.json for the MCP server to become available.**

## Step 3: Authenticate

Ask the user how they want to authenticate. Present these options:

### Option A: CLI Authentication (Recommended)

This authenticates the `endorctl` CLI directly, which handles most scanning operations. It opens a browser for OAuth login and caches credentials locally.

First, ask which auth provider they use:

| Provider | `--auth-mode` value | Additional Flags |
|----------|---------------------|------------------|
| Google | `google` | None |
| GitHub | `github` | None |
| GitLab | `gitlab` | None |
| Enterprise SSO | `sso` | `--auth-tenant <tenant-name>` |
| Browser (generic) | `browser-auth` | None |

Then run `endorctl init` with their chosen provider. The namespace (`-n`) should use the value from Step 4, so if the user already knows their namespace, include it here. Otherwise use `demo-trial` as a placeholder and update later.

```bash
# Google (default)
npx -y endorctl init --auth-mode google -n <namespace>

# GitHub
npx -y endorctl init --auth-mode github -n <namespace>

# GitLab
npx -y endorctl init --auth-mode gitlab -n <namespace>

# Enterprise SSO
npx -y endorctl init --auth-mode sso --auth-tenant <tenant-name> -n <namespace>
```

This will open a browser window for the user to complete the login flow. After successful authentication, credentials are cached locally by `endorctl`.

Verify CLI authentication succeeded:

```bash
npx -y endorctl auth --print-access-token -n <namespace>
```

If this prints a token, CLI auth is working.

After CLI auth succeeds, also update `ENDOR_MCP_SERVER_AUTH_MODE` in `settings.json` to match the same provider so the MCP server uses the same auth method:

```json
"ENDOR_MCP_SERVER_AUTH_MODE": "google"
```

### Option B: MCP Server Auth Only

If the user prefers not to run CLI auth separately, they can rely on the MCP server's built-in authentication. On the first MCP tool call, the server will automatically open a browser window for login. The token is cached for 1 hour.

Set the auth mode in `settings.json`:

| Provider | `ENDOR_MCP_SERVER_AUTH_MODE` | Additional Env Vars |
|----------|-------------------------------|---------------------|
| Google | `google` | None |
| GitHub | `github` | None |
| GitLab | `gitlab` | None |
| Enterprise SSO | `sso` | `ENDOR_MCP_SERVER_AUTH_TENANT` |
| Email | `email` | `ENDOR_MCP_SERVER_AUTH_EMAIL` |

### Option C: API Key Auth (CI/CD / Headless)

For CI/CD pipelines or headless environments where no browser is available, use API key authentication.

Instruct the user to set these environment variables themselves (never ask them to paste credentials into chat):

```bash
export ENDOR_API_CREDENTIALS_KEY=<your-api-key>
export ENDOR_API_CREDENTIALS_SECRET=<your-api-secret>
```

These can also be added to the `env` block in `settings.json` for the MCP server:

```json
"env": {
  "ENDOR_NAMESPACE": "<namespace>",
  "ENDOR_API": "https://api.endorlabs.com",
  "ENDOR_API_CREDENTIALS_KEY": "<your-api-key>",
  "ENDOR_API_CREDENTIALS_SECRET": "<your-api-secret>"
}
```

Or use a pre-existing token:

```bash
export ENDOR_TOKEN=<your-token>
```

For headless CLI auth (no browser available but using OAuth):

```bash
npx -y endorctl init --auth-mode google --headless-mode -n <namespace>
```

This prints a URL that the user can open on any device to complete authentication.

## Step 4: Configure Namespace

### 4.1 Ask for their namespace

The namespace is their Endor Labs organization name. They can find it at [app.endorlabs.com](https://app.endorlabs.com) in the top-left corner.

### 4.2 Update settings.json

Replace `"your-namespace"` with their actual namespace in the `ENDOR_NAMESPACE` field.

If they don't have a namespace yet, `demo-trial` provides limited demo access.

### 4.3 If the user used CLI auth (Option A in Step 3)

The namespace was already passed via `-n <namespace>` during `endorctl init`. Make sure the same namespace is set in `settings.json` so the MCP server uses it too.

If they used a placeholder namespace during init, re-run with the correct one:

```bash
npx -y endorctl init --auth-mode <their-auth-mode> -n <actual-namespace>
```

### 4.4 For new users without an account

Direct them to:
- Sign up at [endorlabs.com](https://www.endorlabs.com) (free tier available)
- Or run `/endor-demo` to try with simulated data

## Step 5: Verify Setup

### 5.1 Verify CLI Authentication

If the user used CLI auth (Option A), verify the CLI can authenticate:

```bash
npx -y endorctl auth --print-access-token -n <namespace>
```

If this prints a token (a long base64 string), CLI authentication is working.

### 5.2 Verify MCP Server Connection

After restarting Claude Code, try using one of the MCP tools to verify the MCP server connection:

Use the `check_dependency_for_vulnerabilities` MCP tool with a known package:
- ecosystem: `npm`
- dependency_name: `lodash`
- version: `4.17.20`

If this returns vulnerability data, the MCP server setup is working.

If it opens a browser for authentication, that's expected on first use (for Option B users). Complete the login flow.

## Step 6: Success

Congratulate the user and provide next steps:

```markdown
## Setup Complete!

Your Endor Labs MCP server is configured and ready. Here's what to try:

### First Steps
1. `/endor-scan` - Scan your current project for security issues
2. `/endor-check express 4.17.1` - Check a dependency for vulnerabilities
3. `/endor-help` - See all available commands

### Daily Workflow
- Run `/endor-scan` regularly during development
- Use `/endor-check` when adding new dependencies
- Run `/endor-review` before creating pull requests

### Learn More
- `/endor-demo` - Interactive demo with sample data
- `/endor-help` - Full command reference
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `node: command not found` | Install Node.js v18+ (see Step 1) |
| `npx: command not found` | Install Node.js v18+ (npx is bundled) |
| `endorctl: not found via npx` | Check internet connection; run `npx -y endorctl --version` |
| MCP tools not showing in Claude Code | Restart Claude Code after editing settings.json |
| Browser auth not opening | Check `--auth-mode` flag or `ENDOR_MCP_SERVER_AUTH_MODE` is set correctly |
| `endorctl init` fails | Ensure internet access and correct `--auth-mode`; try `--auth-mode browser-auth` as fallback |
| `auth --print-access-token` returns error | Token may have expired; re-run `endorctl init` to re-authenticate |
| CLI auth works but MCP tools fail | Ensure `ENDOR_MCP_SERVER_AUTH_MODE` in settings.json matches the `--auth-mode` used in `endorctl init` |
| `namespace not found` | Verify namespace matches your org name at app.endorlabs.com; ensure same namespace in both CLI (`-n`) and settings.json |
| `permission denied` | Verify your account has access to the namespace |
| Timeout on first run | First `npx` run downloads the package - this may take 30-60 seconds |
| Behind a corporate proxy | Set `HTTPS_PROXY` environment variable in settings.json env block |
| Headless environment, no browser | Use `endorctl init --headless-mode` or API key auth (Option C) |

## Available MCP Tools After Setup

Once configured, these tools are available to Claude Code:

| Tool | Description |
|------|-------------|
| `scan` | Scan repository for vulnerabilities, secrets, SAST issues |
| `check_dependency_for_vulnerabilities` | Check a specific package version for CVEs |
| `get_endor_vulnerability` | Get detailed CVE/GHSA vulnerability information |
| `get_resource` | Retrieve any Endor Labs resource (Project, Finding, Policy, etc.) |
