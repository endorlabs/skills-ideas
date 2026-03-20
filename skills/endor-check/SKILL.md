---
name: endor-check
description: >
  Check if a specific dependency has known vulnerabilities or malware using Endor Labs.
  Use when the user names a package and wants to know if it's safe, says "check lodash",
  "is express vulnerable", "any CVEs in django", "endor check", "is this package safe",
  or provides a package name after installing a dependency. Do NOT use for scanning an
  entire repo (/endor-scan) or viewing existing findings (/endor-findings).
---

# Endor Labs Dependency Check

Check a specific dependency for known vulnerabilities and malware risks.

## Input Parsing

Extract from user input:
1. **Package name** (required) — e.g., `lodash`, `express`, `django`
2. **Version** (optional) — e.g., `4.17.15`, `2.0.0`
3. **Language** (optional) — auto-detect from package name pattern or manifest files in cwd; ask if ambiguous

### Ecosystem Mapping

| Package Manager | `ecosystem` Parameter |
|-----------------|----------------------|
| npm/yarn/pnpm | `npm` |
| pip/poetry | `python` |
| Go modules | `go` |
| Maven | `maven` (use `groupid:artifactid` for dependency name) |
| Gradle | `java` |
| Cargo | `rust` |
| NuGet | `dotnet` |
| RubyGems | `ruby` |
| Composer | `php` |

## Workflow

### Step 1: Check for Vulnerabilities and Risks

**Preferred:** Use `check_dependency_for_risks` MCP tool with `ecosystem`, `dependency_name`, and `version`. This checks for both vulnerabilities AND malware.

**Fallback:** If `check_dependency_for_risks` is unavailable, use `check_dependency_for_vulnerabilities` MCP tool (same parameters, vulnerabilities only).

### Step 2: Present Results

#### If Vulnerabilities or Risks Found

```markdown
## Security Check: {package}@{version}

**Status:** {VULNERABLE / MALWARE DETECTED / VULNERABLE + MALWARE}
**Language:** {language}

### Vulnerabilities Found

| CVE | Severity | Description | Fixed In |
|-----|----------|-------------|----------|
| {cve} | Critical | {desc} | {fixed_version} |

### Malware Risks (if detected)

| Risk | Severity | Description |
|------|----------|-------------|
| {risk_type} | {severity} | {description} |

### Recommended Action

Upgrade to **{safe_version}** to resolve all known vulnerabilities.
If malware detected: **Remove this package immediately** and find a safe alternative.
```

For install commands, read `references/install-commands.md`.

```markdown
### Next Steps

1. `/endor-fix {top-cve}` — Get fix details
2. `/endor-upgrade-impact {package} {safe_version}` — Check upgrade impact
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
