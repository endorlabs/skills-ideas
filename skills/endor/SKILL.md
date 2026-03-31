---
name: endor
description: >
  Main Endor Labs security router. Use when the user says "endor", "endor labs",
  or asks a general security question without specifying a particular endor command.
  Routes ambiguous requests like "check my security", "help with this dependency",
  or "what security tools are available" to the right specialized skill. Do NOT use
  when the user names a specific command like /endor-scan, /endor-check, /endor-fix,
  etc. — those skills handle themselves directly.
---

# Endor Labs Security Assistant

Detect user intent and route to the appropriate specialized skill.

## Routing Table

| User Intent | Route To |
|-------------|----------|
| First-time setup, auth issues | `/endor-setup` |
| Try without account, demo | `/endor-demo` |
| Available commands, help | `/endor-help` |
| Quick scan, scan my code | `/endor-scan` |
| Full/deep/reachability scan | `/endor-scan-full` |
| Check specific dependency | `/endor-check` |
| Show findings, list vulns | `/endor-findings` |
| Fix/remediate vulnerability | `/endor-fix` |
| Upgrade dependency, impact analysis | `/endor-upgrade-impact` |
| Explain CVE, what is CVE-XXXX | `/endor-explain` |
| Package score/health | `/endor-score` |
| SCA, vulnerable dependencies | `/endor-sca` |
| Secrets scan, exposed keys | `/endor-secrets` |
| SAST, static analysis | `/endor-sast` |
| AI SAST results, AI static analysis | `/endor-ai-sast` |
| License check/compliance | `/endor-license` |
| PR review, pre-merge check | `/endor-review` |
| SBOM | `/endor-sbom` |
| CI/CD, pipeline, GitHub Actions | `/endor-cicd` |
| Container/Docker scan | `/endor-container` |
| Policy, enforcement | `/endor-policy` |
| API query, raw API | `/endor-api` |

## Ambiguous Requests

If intent is unclear, ask a clarifying question:
- "check my security" -> Quick scan or full reachability scan?
- "help with this dependency" -> Check vulns, upgrade, or view score?

## First-Time User Detection

If any MCP tool call fails with auth/namespace error:
1. Suggest `/endor-setup`
2. Offer `/endor-demo` to try without an account

## Error Handling

| Error | Action |
|-------|--------|
| Auth error | Route to `/endor-setup` |
| Namespace error | Set `ENDOR_NAMESPACE` or `/endor-setup` |
| MCP server unavailable | Check `endorctl` installed and MCP configured |
| Unknown error | Show error, suggest `/endor-help` |

For data source policy, read references/data-sources.md.

## Response Style

- Be concise and actionable
- Prioritize critical/reachable findings first
- Use tables for structured data
- Provide copy-pasteable commands
- End with suggested next steps

## MCP Fallback Policy

MCP tools are the primary path for all Endor Labs operations. CLI fallback (`npx -y endorctl`) should only be used when the user explicitly confirms MCP is unavailable. Never silently fall back to CLI — if MCP fails, show the error and suggest `/endor-setup`. Always use `npx -y endorctl` (not bare `endorctl`) for CLI commands to ensure auto-installation.

## Error Reporting

Show exact error messages from MCP tools or CLI — do not guess at causes or fabricate diagnoses. For unrecognized errors, suggest `/endor-troubleshoot`.
