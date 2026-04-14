# Endor Labs Monorepo - Claude Code Configuration

## Project Overview

This is the Endor Labs monorepo. It contains the source code for Endor Labs products including `endorctl`, the AI-powered security scanning CLI.

## Endor Labs MCP Server

This project is configured with the Endor Labs MCP server, which provides AI-assisted security tools directly within Claude Code.

### Available MCP Tools

The following tools are available through the `endor-cli-tools` MCP server:

| Tool | Description |
|------|-------------|
| `scan` | Scan a repository for security issues (vulnerabilities, secrets, SAST, dependencies, GitHub Actions) |
| `check_dependency_for_vulnerabilities` | Check if a specific dependency version has known vulnerabilities |
| `check_dependency_for_risks` | Broader risk check including vulnerabilities AND malware detection (superset of above) |
| `get_endor_vulnerability` | Retrieve detailed information about a vulnerability by CVE or GHSA ID |
| `get_resource` | Retrieve any Endor Labs resource (Project, PackageVersion, Vulnerability, Finding, Metric, etc.) |
| `security_review` | AI-powered security review of code diffs (staged + unstaged vs HEAD). Enterprise Edition only. |

### Tool Parameter Reference

#### scan
```json
{
  "path": "/absolute/path/to/repo",
  "scan_types": ["vulnerabilities", "secrets", "dependencies", "sast", "ghactions"],
  "scan_options": { "quick_scan": true, "pr_incremental": false, "pr_baseline": false }
}
```

#### check_dependency_for_vulnerabilities
```json
{
  "ecosystem": "npm|python|java|go|maven",
  "dependency_name": "package-name",
  "version": "1.0.0"
}
```
Note: For Maven packages, use `groupid:artifactid` format for `dependency_name`.

#### check_dependency_for_risks
```json
{
  "ecosystem": "npm|python|java|go|maven",
  "dependency_name": "package-name",
  "version": "1.0.0"
}
```
Same parameters as `check_dependency_for_vulnerabilities` but also detects malware. Prefer this tool when available.

#### get_endor_vulnerability
```json
{
  "vuln_id": "CVE-2024-XXXXX"
}
```
Supports CVE IDs (`CVE-xxxx-xxxx`) and GitHub Security Advisories (`GHSA-xxxx-xxxx-xxxx`).

#### get_resource
```json
{
  "uuid": "resource-uuid",
  "name": "resource-name",
  "resource_type": "Project|PackageVersion|Vulnerability|Finding|Metric|ScanRequest|ScanResult|Policy"
}
```
Provide either `uuid` (preferred) or `name`. The `resource_type` is required.

#### security_review
Analyzes local uncommitted changes (staged and unstaged) compared to HEAD, or diffs between the main branch and the last commit. Requires Enterprise Edition with AI security code review enabled in the platform.

### Authentication

The MCP server authenticates via browser-based OAuth. On first use, a browser window will open for authentication. Supported auth modes:
- `google` - Sign in with Google (default for this repo)
- `github` - Sign in with GitHub
- `gitlab` - Sign in with GitLab
- `sso` - Enterprise SSO (requires `ENDOR_MCP_SERVER_AUTH_TENANT`)
- `email` - Email/password (requires `ENDOR_MCP_SERVER_AUTH_EMAIL`)

### Environment Variables

**Auth workflow note:** Two mutually exclusive auth workflows exist. **Local Development** uses `~/.endorctl/config.yaml` (via `endorctl init`) with no auth env vars. **Multi-Namespace** uses env vars below with no `config.yaml`. Never use both — it causes an auth error loop. See `/endor-setup` for details.

**Security:** Never run **`cat ~/.endorctl/config.yaml`** (or `grep`/`grep -v` it) in Bash — that file contains API credentials and Claude logs tool output. Use **`test -f`** for existence only; see **`rules/endor-safety.md`**.

| Variable | Description | Default | Workflow |
|----------|-------------|---------|----------|
| `ENDOR_NAMESPACE` | Your Endor Labs namespace (organization) | `demo-trial` | Multi-Namespace only |
| `ENDOR_API` | Endor Labs API endpoint | `https://api.endorlabs.com` | Multi-Namespace only |
| `ENDOR_MCP_SERVER_AUTH_MODE` | Authentication method | `google` | Multi-Namespace only |
| `ENDOR_MCP_SERVER_AUTH_TENANT` | SSO tenant (required for `sso` mode) | - | Multi-Namespace only |
| `ENDOR_MCP_SERVER_AUTH_EMAIL` | Auth email (required for `email` mode) | - | Multi-Namespace only |
| `ENDOR_TOKEN` | Pre-existing auth token (skips browser auth) | - | Either |
| `ENDOR_MCP_SERVER_PORT` | HTTP mode port | `8181` | Either |
| `ENDOR_MCP_SERVER_USE_HTTP` | Use HTTP/SSE instead of stdio | `false` | Either |
| `ROOT_DIR` | Root directory for scans | - | Either |
| `GITHUB_TOKEN` | GitHub API token for code navigation | - | Either |

### Scan Environment Variables

When running scans via MCP, prefix scan-related environment variables with `MCP_` (e.g., `MCP_ENDOR_SCAN_LANGUAGES=go`). The MCP server automatically strips the `MCP_` prefix before passing them to the scan engine.

## Endor Labs Skills

This repo includes Claude Code skills for security workflows. Use `/endor-help` to see all available commands. Key commands:

- `/endor-scan` - Quick security scan
- `/endor-check <package>` - Check a dependency for vulnerabilities and malware
- `/endor-fix <CVE>` - Get remediation guidance
- `/endor-review` - Pre-PR security review
- `/endor-ghactions` - GitHub Actions workflow security scan
- `/endor-setup` - First-time setup wizard

### Security Hooks

This repo uses Claude Code hooks to route to Endor Labs skills at the right moments. See `hooks/README.md` for full documentation.

| Hook | Event | What It Does |
|------|-------|--------------|
| `check-dep-install.sh` | PostToolUse (Bash) | Detects dep installs → `/endor-check` |
| `check-manifest-edit.sh` | PostToolUse (Edit/Write) | Detects manifest edits → `/endor-check` |
| `suggest-license-check.sh` | PostToolUse (Bash) | Suggests `/endor-license` after dep installs |
| `post-scan-routing.sh` | PostToolUse (MCP scan) | Routes scan results → `/endor-findings`, `/endor-fix` |
| `mcp-error-recovery.sh` | PostToolUse (MCP tools) | Handles MCP errors → `/endor-setup` |
| `detect-pr-intent.sh` | UserPromptSubmit | Detects PR intent → `/endor-review` |
| `suggest-endor-tools.sh` | UserPromptSubmit | Suggests `/endor-*` skills for CVE/package mentions |
| `session-review-reminder.sh` | Stop | Reminds to run `/endor-review` before PR |

## Repository Structure

```
skills/          - Claude Code skills (slash commands)
  references/    - Shared reference docs for all skills
  endor-*/       - Individual skill directories (25+ skills)
hooks/           - Hooks (route to Endor Labs skills at the right moments)
rules/           - Automatic security rules
settings.json    - MCP server and hooks configuration template
CLAUDE.md        - Project instructions for Claude Code
```

## Development Guidelines

- Always scan code for security issues before committing using `/endor-sast`
- Check new dependencies for vulnerabilities using `/endor-check`
- Run `/endor-review` before creating pull requests
- Use parameterized queries for all database operations
- Never hardcode secrets - use environment variables
- Follow the existing code patterns in each language directory
