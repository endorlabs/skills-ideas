---
name: endor-explain
description: >
  Get detailed information about a specific CVE or security finding. Use when the user
  says "what is CVE-2024-XXXXX", "explain this vulnerability", "tell me about GHSA-...",
  "endor explain", "finding details", or wants to understand severity, impact, attack
  vectors, and affected versions for a specific issue. Do NOT use for fixing a vuln
  (/endor-fix) or listing all findings (/endor-findings).
---

# Endor Labs Vulnerability Explainer

Provide detailed information about a specific CVE or security finding.

## Input Parsing

Accepted inputs:
1. **CVE ID** - e.g., `CVE-2021-23337`
2. **Finding UUID** - from `/endor-findings` output
3. **Package + description** - e.g., "lodash prototype pollution"

## For CVE Lookup

### Step 1: Get Vulnerability Details

Use `get_endor_vulnerability` with the CVE ID.

### Step 2: Check Project Impact

Use `check_dependency_for_risks` (preferred, checks vulnerabilities + malware) or `check_dependency_for_vulnerabilities` (fallback) against project manifest files to determine if affected.

### Step 3: Present

```markdown
## {CVE-ID}: {Title}

### Overview

| Field | Value |
|-------|-------|
| CVE | {cve_id} |
| Severity | {severity} (CVSS: {score}) |
| CWE | {cwe_id} - {cwe_name} |
| Published | {date} |
| EPSS Score | {score}% exploitation probability |

### Description
{Detailed description}

### Impact
{What an attacker could do}

### Attack Vector
**CVSS Vector:** {vector_string}

| Component | Value |
|-----------|-------|
| Attack Vector | {Network/Adjacent/Local/Physical} |
| Attack Complexity | {Low/High} |
| Privileges Required | {None/Low/High} |
| User Interaction | {None/Required} |

### Affected Versions

| Package | Affected | Fixed |
|---------|----------|-------|
| {pkg} | {range} | {version} |

### Your Project
- **Affected:** {Yes/No}
- **Reachable:** {Yes/No} (if affected)
- **Package:** {package}@{version} (if affected)

### Remediation
1. Upgrade to {package}@{fixed_version}
2. Verify: `/endor-check {package} {fixed_version}`
3. Check impact: `/endor-upgrade-impact {package} {fixed_version}`
```

## For Finding UUID Lookup

### Step 1: Get Finding

Use `get_resource` with `resource_type: Finding` and the UUID.

### Step 2: Get Related CVE

If finding references a CVE, also call `get_endor_vulnerability` for full details.

### Step 3: Present

```markdown
## Finding: {title}

| Field | Value |
|-------|-------|
| UUID | {uuid} |
| Category | {vulnerability/sast/secrets/license} |
| Severity | {level} |
| Reachable | {yes/no/n/a} |
| Package | {package}@{version} |
| File | {file_path}:{line} |

### Description
{Details}

### Code Context
{For SAST: show vulnerable code with context}

### Next Steps
1. `/endor-fix {cve_or_id}` to fix
2. `/endor-findings` for related findings
```

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| CVE not found | Check ID format; suggest [app.endorlabs.com](https://app.endorlabs.com). Do NOT search external DBs. |
| Finding UUID not found | May be resolved or UUID incorrect |
| Auth error | Run `/endor-setup` |
