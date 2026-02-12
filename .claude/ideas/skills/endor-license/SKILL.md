---
name: endor-license
description: |
  Analyze license compliance, identify license risks, and check compatibility of dependency licenses with your project.
  - MANDATORY TRIGGERS: endor license, license check, license compliance, license risk, copyleft, gpl check, endor-license, license scan
---

# Endor Labs License Compliance

Analyze dependency licenses for compliance risks and compatibility.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)

## License Categories

### Permissive (Low Risk)
MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, Unlicense, CC0-1.0, WTFPL

### Weak Copyleft (Medium Risk - Review Required)
LGPL-2.1, LGPL-3.0, MPL-2.0, EPL-2.0, CDDL-1.0

### Strong Copyleft (High Risk)
GPL-2.0, GPL-3.0, AGPL-3.0, SSPL, OSL-3.0

### Unknown/No License (High Risk)
No license, custom license, proprietary, UNLICENSED

## Workflow

### Step 1: Get License Findings

Run a scan focused on dependencies to get license findings:

Use the `scan` MCP tool:
- `path`: Absolute path to the repository
- `scan_types`: `["dependencies"]`
- `scan_options`: `{ "quick_scan": true }`

Then use `get_resource` MCP tool with `resource_type: Finding` for each finding UUID returned.

Alternatively, use the CLI (always redirect stderr with `2>/dev/null` when piping to a JSON parser):
```bash
npx -y endorctl api list --resource Finding -n $ENDOR_NAMESPACE --filter "spec.finding_categories contains FINDING_CATEGORY_LICENSE_RISK" 2>/dev/null
```

**CLI parsing notes:** `spec.remediation` is a plain string (not a nested object), and `spec.target_dependency_package_name` includes an ecosystem prefix (e.g., `pypi://django@4.2`) that should be stripped for display.

### Step 2: Analyze Manifest Files

Also scan the project's dependency manifest to build a complete license inventory. Read the manifest files (package.json, go.mod, etc.) to identify all dependencies.

### Step 3: Present Results

```markdown
## License Compliance Report

**Project:** {project name}
**Dependencies Analyzed:** {count}

### License Summary

| Category | Count | Risk |
|----------|-------|------|
| Permissive (MIT, Apache, BSD) | {n} | Low |
| Weak Copyleft (LGPL, MPL) | {n} | Medium |
| Strong Copyleft (GPL, AGPL) | {n} | High |
| Unknown/No License | {n} | High |

### License Risks Found

| # | Package | License | Risk | Issue |
|---|---------|---------|------|-------|
| 1 | {pkg} | GPL-3.0 | High | Copyleft - may require open-sourcing your code |
| 2 | {pkg} | AGPL-3.0 | Critical | Network copyleft - affects SaaS usage |
| 3 | {pkg} | UNLICENSED | High | No permission to use |

### Detail: {Risk #1}

**Package:** {package}@{version}
**License:** {license}
**Category:** Strong Copyleft
**Risk Level:** High

**Implications for your project:**
- If your project is proprietary/commercial, using this package may require you to:
  - Release your source code under the same license
  - Provide source code to all users
  - License your entire project under this license

**Alternatives:**

| Package | License | Description |
|---------|---------|-------------|
| {alt1} | MIT | Similar functionality |
| {alt2} | Apache-2.0 | Alternative approach |

**Options:**
1. Use an alternative package with a permissive license
2. Isolate usage as a separate process (consult legal)
3. Accept the copyleft license and open-source your project
4. Contact the maintainer to request a license exception

### Full License Inventory

| Package | License | Category | Risk |
|---------|---------|----------|------|
| {pkg1} | MIT | Permissive | Low |
| {pkg2} | Apache-2.0 | Permissive | Low |
| {pkg3} | LGPL-3.0 | Weak Copyleft | Medium |
| {pkg4} | GPL-3.0 | Strong Copyleft | High |

### Recommendations

1. **Replace high-risk dependencies** with permissive alternatives where possible
2. **Review LGPL usage** - ensure dynamic linking compliance
3. **Add license checks to CI/CD** with `/endor-cicd`
4. **Consult legal** for any copyleft dependencies in commercial projects

### Next Steps

1. **Fix license issues:** Replace packages listed above
2. **Set policy:** `/endor-policy` to enforce license rules
3. **Full scan:** `/endor-scan` for complete security analysis
```

## Compatibility Matrix

When reporting, use this compatibility reference:

### For Commercial/Proprietary Projects

| License | Compatible | Action |
|---------|-----------|--------|
| MIT, Apache, BSD | Yes | Allow |
| LGPL | Review | Check linking method |
| GPL | No | Block or replace |
| AGPL | No | Block or replace |
| Unknown | No | Block until resolved |

### For Open Source (MIT/Apache) Projects

| License | Compatible | Action |
|---------|-----------|--------|
| MIT, Apache, BSD | Yes | Allow |
| LGPL | Yes | Allow |
| GPL | Partial | May affect project license |
| AGPL | No | Block or replace |

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for license or package information.** All license data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit package registries to look up licenses. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

- **No license findings**: Either no issues exist or no scan has been run. Suggest `/endor-scan`.
- **Auth error**: Suggest `/endor-setup`
