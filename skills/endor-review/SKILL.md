---
name: endor-review
description: >
  Pre-PR security review of your current branch or git diff. Use when the user says
  "review my changes", "ready to merge", "pre-PR check", "security review before PR",
  "endor review", or is about to create a pull request. Runs dependency checks, SAST,
  secrets detection, and license compliance as a security gate. Do NOT use for scanning
  repos outside the current branch (/endor-scan) or checking individual packages
  (/endor-check).
---

# Endor Labs Pre-PR Security Review

Comprehensive security review of changes before creating a pull request.

## Workflow

### Step 1: Gather Changes and Run PR Scan

```bash
git diff --name-only HEAD          # Changed files (staged + unstaged)
git diff HEAD                      # Full diff
git diff main...HEAD --name-only   # Branch comparison
```

Categorize changed files into: dependency manifests, source code, config files, CI/CD files.

**Run incremental PR scan** using `scan` MCP tool:
- `path`: absolute path to repo root
- `scan_types`: `["vulnerabilities", "dependencies", "sast", "secrets"]`
- `scan_options`: `{ "pr_incremental": true }`

This only reports **new findings introduced by the PR**, not pre-existing issues. Fall back to individual checks below if incremental scan unavailable.

### Step 1b: AI Security Review (Enterprise Only)

If available, also use `security_review` MCP tool for AI-powered diff analysis. This provides deeper code-level security insights beyond pattern matching. Results complement the checks below.

### Step 2: Dependency Check

If dependency manifests modified:
1. Parse diff for new/updated packages
2. Use `check_dependency_for_risks` MCP tool for each (checks vulnerabilities AND malware)
3. Fallback to `check_dependency_for_vulnerabilities` if `_risks` unavailable
4. Report vulnerabilities and malware risks found

### Step 3: SAST Analysis

For modified source files (if not covered by Step 1):
1. Use `scan` MCP tool with `scan_types: ["sast"]`
2. Retrieve details with `get_resource` (resource_type: `Finding`)
3. Show code context from affected files

### Step 4: Secrets Detection

If not covered by Step 1:
1. Use `scan` MCP tool with `scan_types: ["secrets"]`
2. Manually check git diff for common secret patterns
3. Flag any exposed credentials

### Step 5: License Check

For new dependencies: check license, flag copyleft (GPL, AGPL), warn on unknown.

### Step 6: Container Security (if applicable)

If Dockerfile/docker-compose modified: check for root user, latest tags, exposed ports, secrets in build args.

### Step 7: Present Security Review

```markdown
## Pre-PR Security Review

**Branch:** {branch} | **Files Changed:** {count} | **Scan Mode:** {Incremental/Full fallback}

### 1. Dependency Check {PASS/WARN/BLOCK}

| Package | Change | Version | Vulnerabilities | Status |
|---------|--------|---------|-----------------|--------|

### 2. SAST Analysis {PASS/WARN/BLOCK}

| File | Issues | Severity | Details |
|------|--------|----------|---------|

### 3. Secrets Scan {PASS/BLOCK}

| Type | File | Line |
|------|------|------|

### 4. License Check {PASS/WARN/BLOCK}

| Package | License | Risk |
|---------|---------|------|

### Verdict: {PASS / WARN / BLOCK}
```

### Security Gate Criteria

| Verdict | Conditions |
|---------|------------|
| **BLOCK** | Critical vuln in new deps, critical SAST finding (SQLi, command injection), any exposed secrets, AGPL/SSPL deps |
| **WARN** | High vulns (non-reachable), medium/low SAST findings, GPL deps |
| **PASS** | No critical issues, no secrets, no blocking licenses |

### Step 8: Actionable Fixes

For each blocking issue:
```markdown
### Required Fixes Before Merge

1. **{Issue}** in {file}:{line}
   - **Fix:** {specific remediation}
   - **Command:** `/endor-fix {cve}` for details
```

For data source policy, read `references/data-sources.md`.

## Error Handling

If a scan partially succeeds (e.g., dependency check works but SAST fails), present the available results with a note about which checks failed. Do not discard partial results.

| Error | Action |
|-------|--------|
| No changes detected | Tell user there are no changes to review |
| Auth error | Suggest `/endor-setup` |
| MCP not available | Perform manual pattern-based review of the diff |
