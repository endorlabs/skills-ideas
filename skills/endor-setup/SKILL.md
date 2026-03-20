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
        "mcp-server",
        "--config-path",
        ".endorctl-mcp"
      ],
      "env": {
        "MCP_ENDOR_CONFIG_PATH": ".endorctl-mcp",
        "ENDOR_MCP_SERVER_AUTH_MODE": "google",
        "ENDOR_API": "https://api.endorlabs.com",
        "ENDOR_NAMESPACE": "demo-trial"
      }
    }
  }
}
```

### 2.3 Create the config directory

```bash
mkdir -p .endorctl-mcp
touch .endorctl-mcp/config.yaml
```

### 2.4 Important: Restart Required

Tell the user: **You must restart Claude Code after creating or modifying settings.json for the MCP server to become available.**

## Step 3: Choose Authentication Method

Ask the user which authentication provider they use:

| Provider | `ENDOR_MCP_SERVER_AUTH_MODE` | Additional Config |
|----------|-------------------------------|-------------------|
| Google | `google` | None |
| GitHub | `github` | None |
| GitLab | `gitlab` | None |
| Enterprise SSO | `sso` | Also set `ENDOR_MCP_SERVER_AUTH_TENANT` |
| Email | `email` | Also set `ENDOR_MCP_SERVER_AUTH_EMAIL` |

Update the `ENDOR_MCP_SERVER_AUTH_MODE` in settings.json accordingly.

On first MCP tool call, the server will automatically open a browser window for authentication. The token is cached for 1 hour.

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

### 4.1 Ask for their namespace

The namespace is their Endor Labs organization name. They can find it at [app.endorlabs.com](https://app.endorlabs.com) in the top-left corner.

### 4.2 Update settings.json

Replace `"demo-trial"` with their actual namespace in the `ENDOR_NAMESPACE` field.

If they don't have a namespace yet, `demo-trial` provides limited demo access.

### 4.3 For new users without an account

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
| Browser auth not opening | Check `ENDOR_MCP_SERVER_AUTH_MODE` is set correctly |
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
