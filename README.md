# Endor Labs Claude Code Skills

Integrate Endor Labs security scanning into your Claude Code development workflow. Scan for vulnerabilities, check dependencies, get remediation guidance, and enforce security policies - all without leaving your editor.

## Quick Start

### Prerequisites

- **Node.js** (v18+) with `npx` available
- **Claude Code** installed and running
- An **Endor Labs account** (free tier available at [endorlabs.com](https://www.endorlabs.com))

### 1. Install the MCP Server

No manual installation needed. The MCP server runs via `npx` using the published `endorctl` npm package. Just ensure Node.js is installed:

```bash
# Verify Node.js is available
node --version   # v18+ required
npx --version    # comes with Node.js
```

### 2. Configure Claude Code

The `.claude/settings.json` in this repository is already configured with the Endor Labs MCP server. If you're setting this up in a new project, create `.claude/settings.json`:

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

### 3. Authenticate

On first use, the MCP server will open a browser window for authentication. Sign in with your preferred provider (Google, GitHub, GitLab, SSO, or email).

If you don't have an account yet, run `/endor-demo` in Claude Code to see a demo with simulated data, or sign up at [endorlabs.com](https://www.endorlabs.com).

### 4. Set Your Namespace

Replace `your-namespace` in settings.json with your Endor Labs namespace (your organization name). If you don't set one, it defaults to `demo-trial`.

### 5. Start Using

Restart Claude Code to pick up the MCP server configuration, then try:

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
| `/endor-sast` | Static application security testing |
| `/endor-secrets` | Find exposed secrets and credentials |
| `/endor-container` | Scan Dockerfiles and container images |

### Dependency Analysis

| Command | Description |
|---------|-------------|
| `/endor-check <package>` | Check a dependency for vulnerabilities |
| `/endor-score <package>` | View package health scores |
| `/endor-upgrade <package>` | Predict upgrade impact and breaking changes |
| `/endor-license` | Check license compliance |

### Findings & Remediation

| Command | Description |
|---------|-------------|
| `/endor-findings` | View security findings with filters |
| `/endor-fix <CVE>` | Get step-by-step remediation guidance |
| `/endor-explain <CVE>` | Detailed vulnerability information |

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

## Security Hooks (Deterministic Enforcement)

Hooks are shell scripts that run **automatically and deterministically** at specific points in Claude Code's lifecycle. Unlike rules (advisory), hooks are guaranteed to execute every time.

See [`.claude/hooks/README.md`](.claude/hooks/README.md) for full documentation, event flow diagrams, and testing instructions.

### Hard Blocks (Tier 1)

| Hook | When | What It Prevents |
|------|------|------------------|
| `protect-files.sh` | Before file edit | Edits to `.env`, `.pem`, `.key`, credentials |

### Warnings (Tier 2)

| Hook | When | What It Detects |
|------|------|-----------------|
| `warn-secrets-at-write.sh` | Before file write | Secret patterns in content being written |
| `warn-insecure-code.sh` | Before file write | Dangerous code patterns (injection, XSS, deserialization) |
| `check-dep-install.sh` | After dep install cmd | New dependencies needing vulnerability check |
| `check-manifest-edit.sh` | After manifest edit | Changed dependencies needing vulnerability check |
| `session-review-reminder.sh` | Session end | Unreviewed security-sensitive file changes |

### Suggestions (Tier 3)

| Hook | When | Suggests |
|------|------|----------|
| `suggest-container-review.sh` | After Dockerfile/compose edit | `/endor-container` + inline pattern warnings |
| `suggest-cicd-review.sh` | After CI/CD config edit | `/endor-cicd` + unpinned action warnings |
| `suggest-sast-review.sh` | After security-sensitive code | `/endor-sast` |
| `warn-iac-patterns.sh` | After Terraform/K8s edit | IaC anti-pattern warnings |
| `suggest-license-check.sh` | After dep install cmd | `/endor-license` |
| `post-scan-routing.sh` | After MCP scan completes | `/endor-findings` → `/endor-fix` workflow |
| `mcp-error-recovery.sh` | After MCP tool error | `/endor-setup` or `/endor-troubleshoot` |
| `detect-pr-intent.sh` | User mentions PR/merge | `/endor-review` |
| `suggest-endor-tools.sh` | User mentions CVE/package | `/endor-explain`, `/endor-score`, `/endor-demo` |
| `session-security-posture.sh` | Session start/compact | Security posture summary |
| `track-security-files.sh` | After file edit (silent) | Tracks modifications for session-end review |

## Automatic Security Rules

This project also includes advisory security rules in `.claude/rules/` that guide Claude's behavior:

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
.claude/
├── settings.json              # MCP server + hooks configuration
├── settings.local.json        # Local overrides (gitignored)
├── hooks/                     # Deterministic security hooks
│   ├── README.md              # Hook documentation
│   ├── protect-files.sh       # [Block] Sensitive file edits
│   ├── warn-secrets-at-write.sh    # [Warn] Secrets at write time
│   ├── warn-insecure-code.sh       # [Warn] Dangerous code patterns
│   ├── check-dep-install.sh        # [Warn] Dep install → /endor-check
│   ├── check-manifest-edit.sh      # [Warn] Manifest edit → /endor-check
│   ├── suggest-container-review.sh  # [Suggest] Dockerfile → /endor-container
│   ├── suggest-cicd-review.sh      # [Suggest] CI/CD → /endor-cicd
│   ├── suggest-sast-review.sh      # [Suggest] Security code → /endor-sast
│   ├── suggest-license-check.sh    # [Suggest] Dep install → /endor-license
│   ├── warn-iac-patterns.sh        # [Suggest] IaC anti-patterns
│   ├── post-scan-routing.sh        # [Suggest] Scan → findings → fix
│   ├── mcp-error-recovery.sh       # [Suggest] MCP errors → setup/troubleshoot
│   ├── detect-pr-intent.sh         # [Suggest] PR intent → /endor-review
│   ├── suggest-endor-tools.sh      # [Suggest] CVE/package → relevant skill
│   ├── session-security-posture.sh  # [Suggest] Session start posture
│   ├── track-security-files.sh     # [Silent] Track sensitive file mods
│   └── session-review-reminder.sh   # [Warn] Session-end review reminder
├── skills/
│   ├── endor/              # Main router skill
│   ├── endor-setup/        # Onboarding wizard
│   ├── endor-demo/         # Demo mode
│   ├── endor-help/         # Command reference
│   ├── endor-scan/         # Quick scan
│   ├── endor-scan-full/    # Full reachability scan
│   ├── endor-check/        # Dependency check
│   ├── endor-findings/     # View findings
│   ├── endor-fix/          # Remediation
│   ├── endor-upgrade/      # Upgrade impact analysis
│   ├── endor-explain/      # CVE details
│   ├── endor-score/        # Package health
│   ├── endor-secrets/      # Secrets detection
│   ├── endor-sast/         # Static analysis
│   ├── endor-license/      # License compliance
│   ├── endor-review/       # Pre-PR review
│   ├── endor-sbom/         # SBOM management
│   ├── endor-cicd/         # CI/CD generation
│   ├── endor-container/    # Container scanning
│   ├── endor-policy/       # Policy management
│   └── endor-api/          # Direct API access
└── rules/
    ├── endor-prevent.md           # Post-tool dependency check rule
    ├── dependency-security.md
    ├── secrets-detection.md
    ├── sast-analysis.md
    ├── license-compliance.md
    ├── container-security.md
    └── pr-security-review.md
```

## Contributing

### Adding New Skills

1. Create a new directory under `.claude/skills/`
2. Add a `SKILL.md` file with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: |
     Description of the skill.
     - MANDATORY TRIGGERS: trigger1, trigger2, trigger3
   ---
   ```
3. Include Prerequisites, Workflow, Output Format, and Error Handling sections
4. Test the skill by running the trigger command in Claude Code

### Adding New Hooks

1. Create a bash script in `.claude/hooks/` with a descriptive header comment
2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. Wire it in `.claude/settings.json` under the appropriate event and matcher
4. Test with pipe: `echo '{"tool_name":"...","tool_input":{...}}' | .claude/hooks/my-hook.sh`
5. Classify by tier: Block (exit 2), Warn (exit 0 + imperative stdout), Suggest (exit 0 + informational stdout)
6. See [`.claude/hooks/README.md`](.claude/hooks/README.md) for design principles and patterns

## Links

- [Endor Labs Documentation](https://docs.endorlabs.com)
- [Endor Labs API Reference](https://docs.api.endorlabs.com)
- [Sign Up for Free](https://www.endorlabs.com)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
