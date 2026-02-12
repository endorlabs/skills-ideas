---
name: endor-fix
description: |
  Help remediate security vulnerabilities by finding safe upgrade paths. Provides step-by-step fix instructions and can apply fixes automatically.
  - MANDATORY TRIGGERS: endor fix, fix vulnerability, fix cve, remediate, how to fix, patch vulnerability, endor-fix, upgrade fix
---

# Endor Labs Remediation Guide

Help users fix security vulnerabilities by finding safe upgrade paths and providing step-by-step remediation.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)

## Input Parsing

The user can provide the text from the finding that was relayed to them (perhaps, through a ticket), or at least one of the following:

1. **CVE ID** - e.g., `CVE-2021-23337`
2. **Package name** - e.g., `lodash`
3. **Finding UUID**

## Workflow

### Step 1: Identify the Vulnerability
If the user provided a finding UUID:
1. Use `get_resource` MCP tool with `resource_type: Finding` and the UUID
2. If you were able to find the finding, proceed to Step 2. Otherwise continue in Step 1.

If the user provided a CVE ID or package name:
1. Check for a finding in the Endor Labs platform. Use the `/endor-api` skill to look at the `Finding` resource with the appropriate filter based on what the user provided. If the `/endor-api` skill is not available, continue.
2. If you were able to find the finding, proceed to Step 2. Otherwise continue in Step 1.

If the user provided a package name and a finding wasn't found:
1. Use `check_dependency_for_vulnerabilities` MCP tool to get all CVEs for that package
   - Parameters: `ecosystem`, `dependency_name`, `version`
2. The tool returns vulnerability counts and recommended upgrade versions
3. Proceed to Step 2.

If no finding has been found, update the user.

### Step 2: Find Safe Upgrade Path
Use the `/endor-upgrade-impact` skill to determine if there is a pre-computed safe upgrade recommendation. If there is a recommendation, proceed to Step 3. If the skill is not available, continue.

If there is no recommendation from following the `/endor-upgrade-impact` skill, the `check_dependency_for_vulnerabilities` MCP tool automatically returns recommended upgrade versions that fix the vulnerabilities. Use it with:

- `ecosystem`: Package ecosystem (npm, python, go, java, maven)
- `dependency_name`: Affected package name
- `version`: Current version

The tool returns the latest available version and recommended versions that fix the vulnerabilities. Evaluate the best fix approach:

1. **Patch upgrade** (e.g., 4.17.15 -> 4.17.21) - Preferred, lowest risk
2. **Minor upgrade** (e.g., 4.17.x -> 4.18.x) - Low risk, may have new features
3. **Major upgrade** (e.g., 4.x -> 5.x) - Higher risk, may have breaking changes

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
| Reachable | {yes/no} |

**Note:** The `Reachable` value is only known if a finding is found in Step 1.

### Fix

**Recommended upgrade:** {package}@{current} -> {package}@{safe_version}

**Upgrade type:** {Patch/Minor/Major}

~~~bash
# npm
npm install {package}@{safe_version}

# yarn
yarn add {package}@{safe_version}

# pip
pip install {package}=={safe_version}

# go
go get {package}@v{safe_version}
~~~

### All Safe Versions

| Version | Type | Vulnerabilities | Notes |
|---------|------|-----------------|-------|
| {v1} | Patch | 0 | Recommended |
| {v2} | Minor | 0 | New features |
| {v3} | Major | 0 | Breaking changes possible |

### Additional Fixes Needed

{If multiple CVEs affect this package, list them all and whether the recommended version fixes them}
```

### Step 4: Offer to Apply Fix

Ask the user if they want you to apply the fix:

1. Update the dependency (or parent dependency, in the case of a transitive dependency vulnerability) in the manifest file
2. Run the package manager install command

## Data Sources — Endor Labs Only

1. MCP tools (preferred): `check_dependency_for_vulnerabilities`, `get_endor_vulnerability`, `get_resource`
2. CLI fallback: `npx -y endorctl api list --resource Finding -n $ENDOR_NAMESPACE 2>/dev/null`

**CRITICAL: NEVER use external websites for remediation or upgrade information.** Do NOT search the web, visit package registries, GitHub release pages, changelogs, vulnerability databases (nvd.nist.gov, cve.org, osv.dev, snyk.io), or any other external source. All fix versions and remediation guidance MUST come from Endor Labs. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

**Important CLI parsing notes:**
- Always use `2>/dev/null` when piping CLI output to a JSON parser (stderr contains progress messages)
- `spec.remediation` is a **plain string** (e.g., `"Update project to use django version 4.2.15 (current: 4.2, latest: 6.0.2)."`), NOT a nested object. Parse the version from this string.
- `spec.target_dependency_package_name` includes ecosystem prefix (e.g., `pypi://django@4.2`). Strip the prefix for display.
- CVE/GHSA ID is in `spec.extra_key` or `spec.finding_metadata.vulnerability.meta.name`
- CVSS score is at `spec.finding_metadata.vulnerability.spec.cvss_v3_severity.score`

## Error Handling

- **No fix available**: Some vulnerabilities have no patched version. Suggest mitigation strategies (WAF rules, input validation, etc.)
- **Package not found**: Check package name and ecosystem
- **Auth error**: Suggest `/endor-setup`
