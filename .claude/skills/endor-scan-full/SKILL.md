---
name: endor-scan-full
description: |
  Comprehensive security scan with full reachability analysis to identify exploitable vulnerabilities. Builds call graphs to determine which vulnerabilities are actually reachable in your code.
  - MANDATORY TRIGGERS: endor scan full, full scan, deep scan, reachability scan, reachability analysis, comprehensive scan, endor-scan-full
---

# Endor Labs Full Reachability Scan

Perform a comprehensive security scan with full call graph analysis. This identifies which vulnerabilities are actually reachable (exploitable) in your code.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)
- Current directory is a repository with source code
- Build tools installed for the project language

## What Makes This Different from Quick Scan

| Feature | Quick Scan | Full Scan |
|---------|-----------|-----------|
| Speed | Seconds | Minutes |
| Reachability | No | Full call graph |
| Call Paths | No | Yes - see how vulnerable code is reached |
| Prioritization | By severity only | By severity + reachability |
| Use Case | Daily development | Pre-release audits, security reviews |

## Workflow

### Step 1: Detect Repository Context

Same as `/endor-scan` - detect languages and manifest files.

### Step 2: Warn About Duration

Tell the user:

> Full reachability analysis builds a call graph of your entire codebase. This typically takes 2-5 minutes depending on project size. I'll keep you updated on progress.

### Step 3: Run Full Scan

Use the `scan` MCP tool with these parameters:

- `path`: The **absolute path** to the repository root (required - must be fully qualified)
- `scan_types`: `["vulnerabilities", "dependencies", "secrets", "sast"]`
- `scan_options`: `{ "quick_scan": false }` (disabling quick_scan enables full reachability analysis)

If the MCP tool returns an error, **report the exact error to the user first** — do NOT guess or fabricate the cause. Only fall back to CLI if the MCP server is genuinely unavailable (not configured or not installed):

```bash
npx -y endorctl scan --path $(pwd) --output-type summary -n <namespace>
```

### Step 4: Present Results

Format results emphasizing reachability:

```markdown
## Full Security Scan Complete

**Path:** {scanned path}
**Languages:** {detected languages}
**Scan Type:** Full Reachability Analysis

### Reachability Summary

| Severity | Total | Reachable | Unreachable |
|----------|-------|-----------|-------------|
| Critical | {n} | {r} | {u} |
| High | {n} | {r} | {u} |
| Medium | {n} | {r} | {u} |
| Low | {n} | {r} | {u} |

> **Key Insight:** Only {reachable_count} of {total_count} vulnerabilities are reachable in your code. Focus remediation on these.

### Critical + Reachable (Fix Now)

| # | Package | CVE | Description | Call Path |
|---|---------|-----|-------------|-----------|
| 1 | {pkg} | {cve} | {desc} | {entry_point} -> ... -> {vuln_func} |

### High + Reachable (Fix Urgently)

| # | Package | CVE | Description | Call Path |
|---|---------|-----|-------------|-----------|
| 1 | {pkg} | {cve} | {desc} | {entry_point} -> ... -> {vuln_func} |

### Unreachable Findings (Lower Priority)

{count} vulnerabilities are present in dependencies but not reachable from your code. These represent a lower risk but should be tracked.

### Next Steps

1. **Fix reachable critical:** `/endor-fix {top-cve}`
2. **Explain a finding:** `/endor-explain {cve}`
3. **View all findings:** `/endor-findings reachable`
4. **Upgrade with impact analysis:** `/endor-upgrade {package}`
```

### Step 5: Finding Details

For each finding UUID returned by the scan, use the `get_resource` MCP tool to retrieve full details:
- `uuid`: The finding UUID
- `resource_type`: `Finding`

The finding data includes reachability information and call paths when available.

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for vulnerability or security information.** All data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external vulnerability databases. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

**CRITICAL: Always report exact error messages to the user. Never fabricate, guess, or invent error diagnoses.**

- **Auth error**: Tell user to complete browser login, then retry. Do NOT bypass by switching to CLI. If persistent, suggest `/endor-setup`.
- **Build fails**: The full scan may need the project to be buildable. Suggest fixing build errors first, or use `/endor-scan` for a quick scan that doesn't require building.
- **Timeout**: Large monorepos may take longer. Suggest scanning a specific subdirectory.
- **MCP not available**: Suggest `/endor-setup`. Only fall back to CLI if the user confirms MCP cannot be configured.
- **Unknown error**: Show the exact error text to the user. Suggest `/endor-troubleshoot`. Do NOT guess the cause.
