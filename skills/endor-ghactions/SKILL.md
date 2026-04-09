---
name: endor-ghactions
description: >
  Scan a repository's GitHub Actions workflows for insecure patterns and vulnerable
  third-party action versions using Endor Labs. Use when the user says "scan GitHub
  Actions", "workflow security", "endor ghactions", "insecure CI workflow",
  "vulnerable action version", "harden my GHA workflows", or focuses on
  `.github/workflows` without asking for a full dependency or secrets scan. Do NOT use
  for combined supply chain reports (/endor-supply-chain), generic quick scans
  (/endor-scan), adding Endor to pipelines (/endor-cicd), or dependency-only checks
  (/endor-check).
---

# Endor Labs GitHub Actions Workflow Security

Scan GitHub Actions workflow files for unsafe patterns (injection risks, unsafe
`pull_request`/`pull_request_target` usage, credential handling, pinning gaps) and for
known-vulnerable versions of marketplace and reusable actions.

## Scope

| Focus | Scan type |
|-------|-----------|
| Workflow YAML under `.github/workflows/` | `ghactions` only |

This skill does **not** run SCA, secrets, or SAST scans — only the GitHub Actions analyzer.

## Workflow

### Step 1: Detect Project Context

1. Determine **absolute path** to the repository root (the directory containing `.git` or the project root the user intends to scan).
2. Check for `.github/workflows/` (files `*.yml` / `*.yaml`). If the directory is missing or empty, say so and still run the scan — the engine may report no workflows found.

### Step 2: Run GitHub Actions Scan

Use the `scan` MCP tool:

- `path`: **absolute path** to repository root
- `scan_types`: `["ghactions"]`
- `scan_options`: `{ "quick_scan": true }`

**CLI fallback** (only if MCP is genuinely unavailable and the user confirms):

```bash
npx -y endorctl scan --path "$(pwd)" --ghactions --output-type summary -n <namespace>
```

Show exact error messages — do not guess at causes.

If the scan returns no findings, distinguish between **no workflows present** vs **workflows present and clean** using scan output and filesystem context.

### Step 3: Retrieve Finding Details

For each critical/high finding UUID returned by `scan`, use `get_resource` with `resource_type`: `Finding` (and `uuid` as provided).

For reachability or workflow-level metadata when present in the resource payload, interpret using `references/reachability-tags.md` where applicable.

### Step 4: Present GitHub Actions Security Report

Use this structure:

```markdown
## GitHub Actions Security Scan

**Repository:** {repo path}
**Workflows directory:** `.github/workflows/` ({file count} files)
**Scan date:** {date}

### Summary

| Metric | Value |
|--------|-------|
| Workflows analyzed | {n} |
| Findings (total) | {n} |
| Critical | {n} |
| High | {n} |
| Medium | {n} |
| Low | {n} |

### Findings

| # | Workflow / file | Issue | Severity | Recommendation |
|---|-----------------|-------|----------|----------------|
| 1 | `{path}` | {short description} | {sev} | {concrete fix: pin SHA, restrict permissions, avoid untrusted inputs, etc.} |

### Patterns to highlight (when present in findings)

- Unpinned or outdated `uses:` references (tags moving, known-vulnerable action versions)
- Overbroad `permissions:` or `GITHUB_TOKEN` usage
- Unsafe use of `pull_request_target`, untrusted `issue_comment` / `labeled` triggers with checkout of untrusted code
- Secrets passed to or logged from untrusted contexts
- Script injection via `github.context` / env interpolation in `run:` steps
- Impostor commits, maintainer compromise, or malicious code at a pinned `uses:` SHA — a full SHA pin only locks a revision; it does not prove the action or publisher is trustworthy

### GitHub Actions Risk Summary

**Overall workflow risk:** {Critical / High / Medium / Low / Clean}

**Top priority:** {one sentence — e.g., pin vulnerable action X to SHA or patched version}
```

### Priority Order

1. Critical findings affecting secret exposure or arbitrary code execution in CI; treat detected impostor commits, maintainer compromise, or malicious code at a pinned `uses:` SHA as critical
2. High findings: vulnerable action versions, dangerous `pull_request_target` patterns
3. Medium: missing pins, excessive permissions
4. Low: style / hardening suggestions

### Next Steps

1. `/endor-fix` or `/endor-explain` — if findings reference a specific CVE/GHSA for an action
2. `/endor-supply-chain` — combined view with dependencies and secrets
3. `/endor-cicd` — add Endor Labs or security gates to GitHub Actions pipelines
4. `/endor-troubleshoot` — if scans fail or results look incomplete

For data source policy, read `references/data-sources.md`.

## Error Handling

Show exact error messages — do not guess at causes. Suggest `/endor-troubleshoot` or `/endor-setup` as appropriate.

| Error | Action |
|-------|--------|
| Auth error / browser opens | Complete browser login, retry |
| Missing auth config | `/endor-setup` |
| No `.github/workflows/` | Report clearly; scan may still run with zero workflow findings |
| Scan timeout | Retry once; suggest smaller path or `/endor-troubleshoot` |
| MCP unavailable | `/endor-setup`; CLI fallback only if user confirms |
| Unknown error | Show exact error, suggest `/endor-troubleshoot` |
