---
name: endor-fix
description: |
  Help remediate security vulnerabilities by finding safe upgrade paths. Uses information from Endor Labs to provides step-by-step fix instructions and can apply fixes automatically.
  - MANDATORY TRIGGERS: endor fix, fix vulnerability, fix cve, remediate finding, remediate vuln, how to fix, patch vulnerability, endor-fix, upgrade fix, vuln fix
---

# Endor Labs Remediation Guide

Help users fix security vulnerabilities with safe upgrade paths and step-by-step remediation.

## Input Parsing

The user may provide finding text (e.g., from a ticket) or at least one of:
1. **CVE ID** — e.g., `CVE-2021-23337`
2. **Package name** — e.g., `lodash`
3. **Finding UUID**

## Workflow

### Step 1: Identify the Finding

**If Finding UUID provided:** Use `get_resource` MCP tool with `resource_type: Finding` and the UUID. If found, go to Step 2.

**If CVE ID or package name provided:** Use `/endor-api` skill to query `Finding` resource with appropriate filter. If found, go to Step 2.

**If package name provided but no finding found:** Use `/endor-check` skill instead.

**If no finding found:** Inform user. Indicate whether they are already at a recommended version.

### Step 2: Find Upgrade Recommendation

Use `/endor-upgrade-impact` skill for pre-computed safe upgrade recommendations. If a recommendation exists, go to Step 3. If unavailable or no recommendation, use `/endor-check` skill instead.

### Step 3: Present Remediation

```markdown
## Remediation: {CVE-ID}

### Vulnerability

| Field | Value |
|-------|-------|
| CVE | {cve_id} |
| Severity | {severity} |
| Package | {package}@{current_version} |
| Description | {description} |
| Reachable | {yes/no — only known if finding found in Step 1} |

### Fix

**Recommended upgrade:** {package}@{current} -> {package}@{safe_version}
**Upgrade type:** {Patch/Minor/Major}
```

For install commands, read `references/install-commands.md`.

```markdown
### Additional Fixes Needed

{If multiple CVEs affect this package, list them all and whether the recommended version fixes them}
```

### Step 4: Offer to Apply Fix

Ask the user if they want you to:
1. Update the dependency (or parent dependency for transitive vulnerabilities) in the manifest file
2. Run the package manager install command

For data source policy, read `references/data-sources.md`.

For CLI field paths and parsing gotchas, read `references/cli-parsing.md`.

## Error Handling

| Error | Action |
|-------|--------|
| No fix available | Suggest mitigation strategies (WAF rules, input validation, etc.) |
| Package not found | Check package name and ecosystem |
| Auth error | Suggest `/endor-setup` |
