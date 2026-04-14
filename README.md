# Endor Labs Claude Code Skills

Integrate Endor Labs security scanning into your Claude Code development workflow. Scan for vulnerabilities, check dependencies, get remediation guidance, and enforce security policies - all without leaving your editor.

## No Warranty
Please be advised that this software is provided on an "as is" basis, without warranty of any kind, express or implied. The authors and contributors make no representations or warranties of any kind concerning the safety, suitability, lack of viruses, inaccuracies, typographical errors, or other harmful components of this software. There are inherent dangers in the use of any software, and you are solely responsible for determining whether this software is compatible with your equipment and other software installed on your equipment.

By using this software, you acknowledge that you have read this disclaimer, understand it, and agree to be bound by its terms and conditions. You also agree that the authors and contributors of this software are not liable for any damages you may suffer as a result of using, modifying, or distributing this software.

## Quick Start

### Prerequisites

- **Node.js** (v18+) with `npx` available
- **Claude Code** installed and running
- An **Endor Labs account** (free tier available at [endorlabs.com](https://www.endorlabs.com))

### Installation

Clone this repo, then symlink the skills, rules, and hooks into your Claude Code config:

```bash
# Option A: User-level install (available in all projects, auto-updates with git pull)
git clone https://github.com/endorlabs/endor-solutions-claude-skills.git /path/to/endor-skills
ln -sf /path/to/endor-skills/skills ~/.claude/skills
ln -sf /path/to/endor-skills/rules ~/.claude/rules
ln -sf /path/to/endor-skills/hooks ~/.claude/hooks
```

```bash
# Option B: Project-level install (team can share via git)
cp -r /path/to/endor-skills/skills .claude/skills
cp -r /path/to/endor-skills/rules .claude/rules
cp -r /path/to/endor-skills/hooks .claude/hooks
```

### Configure the MCP Server

Copy the provided `settings.json` into your `.claude/` directory, or merge it with your existing one:

```bash
# If you don't have a settings.json yet:
cp path/to/endor-solutions-claude-skills/settings.json ~/.claude/settings.json

# Then edit it to set your namespace:
# Replace "your-namespace" with your Endor Labs namespace
```

The MCP server runs via `npx` — no separate installation needed. The settings.json configures it like this:

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

### Authenticate

On first use, the MCP server will open a browser window for authentication. Sign in with your preferred provider (Google, GitHub, GitLab, SSO, or email).

If you don't have an account yet, run `/endor-demo` in Claude Code to see a demo with simulated data, or sign up at [endorlabs.com](https://www.endorlabs.com).

### Start Using

Restart Claude Code to pick up the configuration, then try:

```
/endor-scan          # Scan your repository for security issues
/endor-help          # See all available commands
```

## Available Commands

### Getting Started

| Command | Description |
|---------|-------------|
| `/endor` | Main assistant - describe what you need in natural language |
| `/endor-setup` | Interactive setup wizard |
| `/endor-demo` | Try without an account (simulated data) |
| `/endor-help` | Full command reference |

### Scanning

| Command | Description |
|---------|-------------|
| `/endor-scan` | Quick security scan (seconds) |
| `/endor-scan-full` | Deep scan with reachability analysis (minutes) |
| `/endor-sca` | Dependency vulnerability scan (SCA) |
| `/endor-sast` | Static application security testing |
| `/endor-ai-sast` | View AI-powered SAST findings from platform |
| `/endor-secrets` | Find exposed secrets and credentials |
| `/endor-ghactions` | Scan GitHub Actions workflows for insecure patterns and vulnerable actions |
| `/endor-container` | Scan Dockerfiles and container images |

### Dependency Analysis

| Command | Description |
|---------|-------------|
| `/endor-check <package>` | Check a dependency for vulnerabilities |
| `/endor-score <package>` | View package health scores |
| `/endor-upgrade-impact <package>` | Predict upgrade impact and breaking changes |
| `/endor-license` | Check license compliance |

### Findings & Remediation

| Command | Description |
|---------|-------------|
| `/endor-findings` | View security findings with filters |
| `/endor-fix <CVE>` | Get step-by-step remediation guidance |
| `/endor-explain <CVE>` | Detailed vulnerability information |
| `/endor-troubleshoot` | Diagnose scan errors and failures |

### Compliance & Governance

| Command | Description |
|---------|-------------|
| `/endor-review` | Pre-PR security review |
| `/endor-sbom` | Software Bill of Materials management |
| `/endor-policy` | Security policy management |
| `/endor-cicd` | Generate CI/CD security pipelines |

### Advanced

| Command | Description |
|---------|-------------|
| `/endor-api` | Execute custom API queries |

## MCP Tools Reference

The Endor Labs MCP server exposes the following tools that Claude Code can call:

### scan

Scans a repository for security issues. Supports multiple scan types that can be combined.

**Parameters:**
- `path` (string, required) - Absolute path to the repository root
- `scan_types` (array of strings) - Types to scan: `vulnerabilities`, `secrets`, `dependencies`, `sast`, `ghactions`
- `scan_options` (object) - Options: `quick_scan` (bool, default true), `pr_incremental` (bool), `pr_baseline` (bool)

**Returns:** List of finding UUIDs sorted by severity.

### check_dependency_for_vulnerabilities

Checks if a specific version of a dependency has known vulnerabilities and suggests safe upgrade versions.

**Parameters:**
- `ecosystem` (string, required) - Package ecosystem: `npm`, `python`, `java`, `go`, `maven`
- `dependency_name` (string, required) - Package name (for Maven: `groupid:artifactid`)
- `version` (string, required) - Version to check

**Returns:** Vulnerability details including CVE IDs, severity, and recommended upgrade versions.

### check_dependency_for_risks

Same parameters as `check_dependency_for_vulnerabilities`, but also detects **malware**. Prefer this tool when available — it's a strict superset.

### security_review

AI-powered security review of code diffs. Analyzes staged and unstaged changes compared to HEAD for security issues. Requires Enterprise Edition with AI security code review enabled.

**Returns:** Security findings with code-level context and remediation suggestions.

### get_endor_vulnerability

Retrieves detailed vulnerability information from the Endor Labs database.

**Parameters:**
- `vuln_id` (string, required) - Vulnerability ID (e.g., `CVE-2024-12345` or `GHSA-xxxx-xxxx-xxxx`)

**Returns:** Full vulnerability details including severity, description, affected versions, and remediation.

### get_resource

Retrieves any resource from the Endor Labs database by UUID or name.

**Parameters:**
- `uuid` (string) - Resource UUID (preferred)
- `name` (string) - Resource name (alternative to UUID)
- `resource_type` (string, required) - One of: `Project`, `PackageVersion`, `Vulnerability`, `Finding`, `Metric`, `ScanRequest`, `ScanResult`, `Policy`

**Returns:** Full resource data.

## Authentication Modes

| Mode | Env Var Value | Description | Additional Config |
|------|---------------|-------------|-------------------|
| Google | `google` | Sign in with Google | None |
| GitHub | `github` | Sign in with GitHub | None |
| GitLab | `gitlab` | Sign in with GitLab | None |
| SSO | `sso` | Enterprise SSO | Set `ENDOR_MCP_SERVER_AUTH_TENANT` |
| Email | `email` | Email/password | Set `ENDOR_MCP_SERVER_AUTH_EMAIL` |
| Browser | `browser-auth` | Generic browser auth | None |

Set the auth mode via `ENDOR_MCP_SERVER_AUTH_MODE` in settings.json.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ENDOR_NAMESPACE` | Your Endor Labs namespace | `demo-trial` |
| `ENDOR_API` | API endpoint | `https://api.endorlabs.com` |
| `ENDOR_MCP_SERVER_AUTH_MODE` | Auth method | Auto-detect |
| `ENDOR_MCP_SERVER_AUTH_TENANT` | SSO tenant name | - |
| `ENDOR_MCP_SERVER_AUTH_EMAIL` | Auth email address | - |
| `ENDOR_TOKEN` | Pre-existing auth token (skips browser) | - |
| `GITHUB_TOKEN` | GitHub API token for code navigation | - |

### Scan-Specific Variables

When configuring scan behavior, prefix variables with `MCP_`. The MCP server strips the prefix before passing to the scan engine:

| Variable | Description |
|----------|-------------|
| `MCP_ENDOR_SCAN_LANGUAGES` | Languages to scan (e.g., `go,python`) |
| `MCP_ENDOR_SCAN_PATH` | Default scan path |

## Hooks (Endor Labs Skill Routing)

Hooks are shell scripts that run automatically at specific points in Claude Code's lifecycle. They detect the right moment to invoke an Endor Labs skill and inject reminders into Claude's context.

See [`hooks/README.md`](hooks/README.md) for full documentation, event flow diagrams, and testing instructions.

| Hook | When | What It Does |
|------|------|--------------|
| `check-dep-install.sh` | After dep install cmd | Detects dep installs → `/endor-check` |
| `check-manifest-edit.sh` | After manifest edit | Detects manifest edits → `/endor-check` |
| `suggest-license-check.sh` | After dep install cmd | Suggests `/endor-license` |
| `post-scan-routing.sh` | After MCP scan completes | Routes scan results → `/endor-findings`, `/endor-fix` |
| `mcp-error-recovery.sh` | After MCP tool error | Handles MCP errors → `/endor-setup` |
| `detect-pr-intent.sh` | User mentions PR/merge | Suggests `/endor-review` |
| `suggest-endor-tools.sh` | User mentions CVE/package or GitHub Actions workflows | Suggests relevant `/endor-*` skills |
| `session-review-reminder.sh` | Session end | Reminds to run `/endor-review` |

## Automatic Security Rules

This project includes advisory security rules in `rules/` that guide Claude's behavior:

| Rule | Trigger | Action |
|------|---------|--------|
| **Dependency Security** | Modifying package manifests | Check new deps for vulnerabilities |
| **Secrets Detection** | Modifying config/source files | Detect hardcoded secrets |
| **SAST Analysis** | Writing source code | Check for code vulnerabilities |
| **License Compliance** | Adding dependencies | Check license compatibility |
| **Container Security** | Modifying Dockerfiles | Analyze for misconfigurations |
| **PR Security Review** | Creating PRs | Run comprehensive security check |

## Troubleshooting

### MCP server not starting

1. Verify Node.js v18+ is installed: `node --version`
2. Verify npx is available: `npx --version`
3. Test manually: `npx -y endorctl ai-tools mcp-server --help`
4. Check Claude Code logs for MCP connection errors

### Authentication fails

1. Ensure your browser can open for OAuth flow
2. Try a different auth mode (e.g., switch from `google` to `github`)
3. If behind a proxy, set `HTTPS_PROXY` environment variable
4. For CI/CD (no browser): use API key auth with `ENDOR_API_CREDENTIALS_KEY` and `ENDOR_API_CREDENTIALS_SECRET`

### Namespace not found

1. Verify your namespace at [app.endorlabs.com](https://app.endorlabs.com)
2. Update `ENDOR_NAMESPACE` in `.claude/settings.json`
3. Ensure your account has access to the namespace

### Tools not appearing

1. Restart Claude Code after modifying settings.json
2. Check that the MCP server name is `endor-cli-tools` in settings.json
3. Verify the settings.json is in the project's `.claude/` directory

## Project Structure

```
skills/                        # Claude Code skills (slash commands)
├── references/                # Shared reference docs for all skills
│   ├── cli-parsing.md
│   ├── data-sources.md
│   ├── error-knowledge-base.md
│   ├── install-commands.md
│   └── reachability-tags.md
├── endor/                     # Main router skill
├── endor-setup/               # Onboarding wizard
├── endor-demo/                # Demo mode
├── endor-help/                # Command reference
├── endor-scan/                # Quick scan
├── endor-scan-full/           # Full reachability scan
├── endor-sca/                 # SCA dependency scan
├── endor-check/               # Dependency check
├── endor-findings/            # View findings
├── endor-fix/                 # Remediation
├── endor-upgrade-impact/      # Upgrade impact analysis
├── endor-explain/             # CVE details
├── endor-score/               # Package health
├── endor-secrets/             # Secrets detection
├── endor-ghactions/           # GitHub Actions workflow security
├── endor-sast/                # Static analysis
├── endor-ai-sast/             # AI-powered SAST findings
├── endor-license/             # License compliance
├── endor-review/              # Pre-PR review
├── endor-sbom/                # SBOM management
├── endor-cicd/                # CI/CD generation (templates in references/)
├── endor-container/           # Container scanning
├── endor-policy/              # Policy management
├── endor-api/                 # Direct API access
└── endor-troubleshoot/        # Scan error diagnosis
hooks/                         # Hooks (route to Endor Labs skills)
├── README.md
├── check-dep-install.sh       # Dep install → /endor-check
├── check-manifest-edit.sh     # Manifest edit → /endor-check
├── suggest-license-check.sh   # Dep install → /endor-license
├── post-scan-routing.sh       # Scan → /endor-findings → /endor-fix
├── mcp-error-recovery.sh      # MCP errors → /endor-setup
├── detect-pr-intent.sh        # PR intent → /endor-review
├── suggest-endor-tools.sh     # CVE/package/GHA → relevant /endor-* skill
└── session-review-reminder.sh # Session-end → /endor-review reminder
rules/                         # Always-on security rules
├── endor-prevent.md           # Post-tool dependency check rule
└── endor-safety.md            # MCP safety & usage guardrails
settings.json                  # MCP server + hooks configuration template
CLAUDE.md                      # Project instructions for Claude Code
README.md                      # This file
```

## Contributing

### Adding New Skills

1. Create a new directory under `skills/` using kebab-case naming
2. Add a `SKILL.md` file with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: >
     What it does and when to use it. Include specific trigger phrases the user
     might say. Add "Do NOT use for..." to prevent trigger collisions with
     adjacent skills.
   ---
   ```
3. Include Workflow, Output Format, and Error Handling sections
4. Keep SKILL.md under 500 lines — move detailed references to `references/`
5. Test the skill by running the trigger command in Claude Code

### Adding New Hooks

1. Create a bash script in `hooks/` with a descriptive header comment
2. Make it executable: `chmod +x hooks/my-hook.sh`
3. Wire it in `settings.json` under the appropriate event and matcher
4. Test with pipe: `echo '{"tool_name":"...","tool_input":{...}}' | hooks/my-hook.sh`
5. Classify by tier: Block (exit 2), Warn (exit 0 + imperative stdout), Suggest (exit 0 + informational stdout)
6. See [`hooks/README.md`](hooks/README.md) for design principles and patterns

## Links

- [Endor Labs Documentation](https://docs.endorlabs.com)
- [Endor Labs API Reference](https://docs.api.endorlabs.com)
- [Sign Up for Free](https://www.endorlabs.com)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
