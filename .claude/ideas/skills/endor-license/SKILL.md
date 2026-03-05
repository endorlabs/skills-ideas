---
name: endor-license
description: |
  Analyze license compliance, identify license risks, and check compatibility of dependency licenses with your project.
  - MANDATORY TRIGGERS: endor license, license check, license compliance, license risk, copyleft, gpl check, endor-license, license scan
---

# Endor Labs License Compliance

Analyze dependency licenses for compliance risks and compatibility.

## License Categories

| Category | Licenses | Risk |
|----------|----------|------|
| Permissive | MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, Unlicense, CC0-1.0 | Low |
| Weak Copyleft | LGPL-2.1, LGPL-3.0, MPL-2.0, EPL-2.0, CDDL-1.0 | Medium |
| Strong Copyleft | GPL-2.0, GPL-3.0, AGPL-3.0, SSPL, OSL-3.0 | High |
| Unknown/None | No license, custom, proprietary, UNLICENSED | High |

## Workflow

### Step 1: Get License Findings

Use `scan` MCP tool with `scan_types: ["dependencies"]`, `scan_options: { "quick_scan": true }`. Retrieve details via `get_resource` (resource_type: `Finding`).

CLI fallback:
```bash
npx -y endorctl api list --resource Finding -n $ENDOR_NAMESPACE --filter "spec.finding_categories contains FINDING_CATEGORY_LICENSE_RISK" 2>/dev/null
```

For CLI field paths and parsing gotchas, read references/cli-parsing.md.

### Step 2: Analyze Manifest Files

Read project manifests (package.json, go.mod, etc.) to build a complete license inventory.

### Step 3: Present Results

```markdown
## License Compliance Report

**Project:** {name} | **Dependencies Analyzed:** {count}

### License Summary

| Category | Count | Risk |
|----------|-------|------|
| Permissive (MIT, Apache, BSD) | {n} | Low |
| Weak Copyleft (LGPL, MPL) | {n} | Medium |
| Strong Copyleft (GPL, AGPL) | {n} | High |
| Unknown/No License | {n} | High |

### License Risks

| # | Package | License | Risk | Issue |
|---|---------|---------|------|-------|
| 1 | {pkg} | GPL-3.0 | High | Copyleft - may require open-sourcing |
| 2 | {pkg} | AGPL-3.0 | Critical | Network copyleft - affects SaaS |

For each high-risk finding, provide:
- Implications for proprietary vs. open-source projects
- Permissive-licensed alternatives
- Options: replace, isolate, accept copyleft, request exception

### Full License Inventory

| Package | License | Category | Risk |
|---------|---------|----------|------|

### Next Steps

1. `/endor-policy` — Enforce license rules
2. `/endor-scan` — Full security analysis
3. `/endor-cicd` — Add license checks to CI/CD
```

## Compatibility Matrix

### Commercial/Proprietary Projects

| License | Compatible | Action |
|---------|-----------|--------|
| MIT, Apache, BSD | Yes | Allow |
| LGPL | Review | Check linking method |
| GPL, AGPL | No | Block or replace |
| Unknown | No | Block until resolved |

### Open Source (MIT/Apache) Projects

| License | Compatible | Action |
|---------|-----------|--------|
| MIT, Apache, BSD, LGPL | Yes | Allow |
| GPL | Partial | May affect project license |
| AGPL | No | Block or replace |

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| No license findings | No scan run — suggest `/endor-scan` |
| Auth error | Suggest `/endor-setup` |
