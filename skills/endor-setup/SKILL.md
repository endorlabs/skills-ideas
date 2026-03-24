---
name: endor-setup
description: >
  Onboarding wizard for Endor Labs. Guides users through prerequisites, MCP server
  configuration, authentication, namespace setup, and running their first scan. Use when
  the user says "endor setup", "configure endor", "endor auth", "set up endor", "install
  endor", "endor onboarding", or when any MCP tool fails with an auth or namespace error.
  Do NOT use when the user already has a working setup — route to specific skills instead.
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

### 2.2 Choose Authentication Workflow

Ask the user which workflow fits their use case:

| Workflow | Best For | Auth Source |
|----------|----------|-------------|
| **Local Development** | Single namespace, stable local dev, most developers | API key in `~/.endorctl/config.yaml` via `endorctl init` |
| **Multi-Namespace** | Frequent namespace switching, checking multiple repos | Env vars in `settings.json` (`ENDOR_MCP_SERVER_AUTH_MODE`, `ENDOR_NAMESPACE`) |

**These are mutually exclusive.** Using both simultaneously causes an auth error loop. If the user is unsure, recommend **Local Development** — it's simpler and covers most use cases.

### 2.3 Check for conflicting auth sources

Before proceeding, check for conflicts:

```bash
test -f ~/.endorctl/config.yaml && echo "config.yaml exists"
```

- If `config.yaml` exists and user chose **Multi-Namespace**: warn that it must be removed (`rm -rf ~/.endorctl`) to avoid conflicts
- If `config.yaml` does not exist and user chose **Local Development**: good — `endorctl init` will create it in Step 3

### 2.4 Create settings.json

Create or update `.claude/settings.json` in the project root. Use the template matching the chosen workflow:

**Local Development** (no auth env vars — auth comes from `config.yaml`):

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
      ]
    }
  }
}
```

**Multi-Namespace** (auth via env vars — no `config.yaml`):

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
        "ENDOR_MCP_SERVER_AUTH_MODE": "google",
        "ENDOR_API": "https://api.endorlabs.com",
        "ENDOR_NAMESPACE": "demo-trial"
      }
    }
  }
}
```

### 2.5 Important: Restart Required

Tell the user: **You must restart Claude Code after creating or modifying settings.json for the MCP server to become available.**

## Step 3: Authenticate

### Local Development workflow

1. Ask the user for their auth mode (`google`, `github`, `api-key`) and namespace
2. Run `endorctl init` to generate `~/.endorctl/config.yaml`:

```bash
npx -y endorctl init --auth-mode=<MODE>
```

3. The config.yaml will store the API key and namespace. The MCP server reads it automatically — no env vars needed.

### Multi-Namespace workflow

1. Ask the user which authentication provider they use:

| Provider | `ENDOR_MCP_SERVER_AUTH_MODE` | Additional Config |
|----------|-------------------------------|-------------------|
| Google | `google` | None |
| GitHub | `github` | None |
| GitLab | `gitlab` | None |
| Enterprise SSO | `sso` | Also set `ENDOR_MCP_SERVER_AUTH_TENANT` |
| Email | `email` | Also set `ENDOR_MCP_SERVER_AUTH_EMAIL` |

2. Update the `ENDOR_MCP_SERVER_AUTH_MODE` in settings.json accordingly.
3. On first MCP tool call, the server will automatically open a browser window for authentication. The token is cached for 1 hour.

### For CI/CD or headless environments

Instruct the user to set these environment variables themselves (never ask them to paste credentials into chat):

```bash
export ENDOR_API_CREDENTIALS_KEY=<your-api-key>
export ENDOR_API_CREDENTIALS_SECRET=<your-api-secret>
```

Or use a pre-existing token:

```bash
export ENDOR_TOKEN=<your-token>
```

## Step 4: Configure Namespace

### Local Development workflow

The namespace was configured during `endorctl init` in Step 3. Verify it:

```bash
cat ~/.endorctl/config.yaml
```

If wrong, re-run `npx -y endorctl init`.

### Multi-Namespace workflow

Replace `"demo-trial"` with the user's actual namespace in the `ENDOR_NAMESPACE` field of settings.json. The namespace is their Endor Labs organization name, found at [app.endorlabs.com](https://app.endorlabs.com) in the top-left corner.

### For new users without an account

Direct them to:
- Sign up at [endorlabs.com](https://www.endorlabs.com) (free tier available)
- Or run `/endor-demo` to try with simulated data

## Step 5: Verify Setup

After restarting Claude Code, try using one of the MCP tools to verify the connection:

Use the `check_dependency_for_vulnerabilities` MCP tool with a known package:
- ecosystem: `npm`
- dependency_name: `lodash`
- version: `4.17.20`

If this returns vulnerability data, the setup is working.

If it opens a browser for authentication, that's expected on first use. Complete the login flow.

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
| Browser auth not opening | Check `ENDOR_MCP_SERVER_AUTH_MODE` is set correctly (Multi-Namespace workflow only) |
| Auth error loop / persistent auth failures | Conflict between `config.yaml` and env vars in settings.json — choose one workflow and remove the other (see Authentication Workflows in Step 2.2) |
| `namespace not found` | Verify ENDOR_NAMESPACE matches your org name at app.endorlabs.com |
| `permission denied` | Verify your account has access to the namespace |
| Timeout on first run | First `npx` run downloads the package - this may take 30-60 seconds |
| Behind a corporate proxy | Set `HTTPS_PROXY` environment variable in settings.json env block |

## Available MCP Tools After Setup

Once configured, these tools are available to Claude Code:

| Tool | Description |
|------|-------------|
| `scan` | Scan repository for vulnerabilities, secrets, SAST issues |
| `check_dependency_for_vulnerabilities` | Check a specific package version for CVEs |
| `check_dependency_for_risks` | Check for vulnerabilities AND malware (prefer over above) |
| `get_endor_vulnerability` | Get detailed CVE/GHSA vulnerability information |
| `get_resource` | Retrieve any Endor Labs resource (Project, Finding, Policy, etc.) |
| `security_review` | AI-powered code diff security review (Enterprise only) |
