---
name: endor-check
description: |
  Check if a specific dependency has known vulnerabilities using Endor Labs. Provide a package name and optionally a version to get vulnerability information.
  - MANDATORY TRIGGERS: endor check, check dependency, check package, check vulnerability, is this package safe, endor-check
---

# Endor Labs Dependency Check

Check a specific dependency for known vulnerabilities.

## Input Parsing

Extract from user input:
1. **Package name** (required) — e.g., `lodash`, `express`, `django`
2. **Version** (optional) — e.g., `4.17.15`, `2.0.0`
3. **Language** (optional) — auto-detect from package name pattern or manifest files in cwd; ask if ambiguous

### Ecosystem Mapping

| Package Manager | `ecosystem` Parameter |
|-----------------|----------------------|
| npm/yarn | `npm` |
| pip/poetry | `python` |
| Go modules | `go` |
| Maven | `maven` (use `groupid:artifactid` for dependency name) |
| Gradle | `java` |

## Workflow

### Step 1: Check for Vulnerabilities

Use `check_dependency_for_vulnerabilities` MCP tool with `ecosystem`, `dependency_name`, and `version`.

### Step 2: Present Results

#### If Vulnerabilities Found

```markdown
## Vulnerability Check: {package}@{version}

**Status:** VULNERABLE
**Language:** {language}

### Vulnerabilities Found

| CVE | Severity | Description | Fixed In |
|-----|----------|-------------|----------|
| {cve} | Critical | {desc} | {fixed_version} |

### Recommended Action

Upgrade to **{safe_version}** to resolve all known vulnerabilities.
```

For install commands, read `references/install-commands.md`.

```markdown
### Next Steps

1. `/endor-fix {top-cve}` — Get fix details
2. `/endor-upgrade {package} {safe_version}` — Check upgrade impact
```

#### If No Vulnerabilities Found

Report `{package}@{version}` has no known vulnerabilities in Endor Labs. Suggest `/endor-score {package}` for package health.

For data source policy, read `references/data-sources.md`.

## Error Handling

| Error | Action |
|-------|--------|
| Package not found | Check package name and ecosystem. Do NOT look up externally. |
| Version not found | Show available versions from Endor Labs or check latest |
| Auth error | Suggest `/endor-setup` |
| MCP not available | Suggest `/endor-setup` |
