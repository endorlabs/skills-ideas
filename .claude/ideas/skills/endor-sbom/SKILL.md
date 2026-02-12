---
name: endor-sbom
description: |
  Manage Software Bill of Materials (SBOM) - export, import, analyze, and compare SBOMs. Supports CycloneDX and SPDX formats.
  - MANDATORY TRIGGERS: endor sbom, software bill of materials, sbom export, sbom import, sbom analyze, sbom compare, endor-sbom, generate sbom
---

# Endor Labs SBOM Management

Manage Software Bill of Materials - export, import, analyze, and compare.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)
- Node.js v18+ with `npx` available (for CLI operations)

## Supported Actions

| Action | Description |
|--------|-------------|
| `export` | Generate SBOM from current project |
| `import` | Import and analyze an external SBOM |
| `analyze` | Analyze project's component inventory |
| `compare` | Compare two SBOMs for drift detection |
| `validate` | Check SBOM format compliance |

## Workflow

### Action: Export

#### Step 1: Get Project UUID

Use the `get_resource` MCP tool to find the project:
- `resource_type`: `Project`
- `name`: The project/repository name

If the project hasn't been scanned yet, suggest running `/endor-scan` first.

#### Step 2: Export SBOM

```bash
# CycloneDX format (recommended)
npx -y endorctl sbom export --project-uuid {uuid} --format cyclonedx --output sbom-cyclonedx.json

# SPDX format
npx -y endorctl sbom export --project-uuid {uuid} --format spdx --output sbom-spdx.json
```

#### Step 3: Present Summary

```markdown
## SBOM Export Complete

**Format:** {CycloneDX/SPDX}
**File:** {output_path}
**Project:** {project_name}

### Component Summary

| Type | Count |
|------|-------|
| Libraries | {n} |
| Frameworks | {n} |
| Applications | {n} |
| Total Components | {n} |

### Top-Level Dependencies

| Package | Version | License |
|---------|---------|---------|
| {pkg1} | {v1} | MIT |
| {pkg2} | {v2} | Apache-2.0 |

### Compliance

| Requirement | Status |
|-------------|--------|
| NTIA Minimum Elements | {Pass/Fail} |
| Component names | {Pass/Fail} |
| Component versions | {Pass/Fail} |
| Unique identifiers | {Pass/Fail} |
| Dependency relationships | {Pass/Fail} |
| Author information | {Pass/Fail} |
| Timestamp | {Pass/Fail} |
```

### Action: Analyze

Analyze the current project's component inventory:

1. Run `/endor-scan` if not already scanned
2. Query findings and dependencies
3. Present component breakdown with vulnerability and license status

```markdown
## SBOM Analysis

### Component Inventory

| Category | Count | With Vulns | License Risk |
|----------|-------|------------|--------------|
| Direct dependencies | {n} | {n} | {n} |
| Transitive dependencies | {n} | {n} | {n} |
| Dev dependencies | {n} | {n} | {n} |

### Vulnerability Coverage

- **Components with known CVEs:** {n}/{total}
- **Critical/High CVEs:** {n}
- **Reachable CVEs:** {n}

### License Distribution

| License | Count | Risk |
|---------|-------|------|
| MIT | {n} | Low |
| Apache-2.0 | {n} | Low |
| GPL-3.0 | {n} | High |
```

### Action: Compare

Compare two SBOMs for drift detection:

```markdown
## SBOM Comparison

**Base:** {sbom1_name}
**Current:** {sbom2_name}

### Changes

| Change | Package | Base Version | Current Version |
|--------|---------|-------------|-----------------|
| Added | {pkg} | - | {v} |
| Removed | {pkg} | {v} | - |
| Updated | {pkg} | {v_old} | {v_new} |

### Security Impact

- **New vulnerabilities introduced:** {n}
- **Vulnerabilities resolved:** {n}
- **Net change:** {+/-n}

### License Impact

- **New license risks:** {n}
- **License risks resolved:** {n}
```

### Action: Validate

Validate an SBOM file against compliance standards:

```markdown
## SBOM Validation

**File:** {path}
**Format:** {detected format}
**Valid:** {yes/no}

### Compliance Checks

| Check | Status | Details |
|-------|--------|---------|
| Format validity | {Pass/Fail} | {details} |
| NTIA minimum elements | {Pass/Fail} | {details} |
| Component completeness | {Pass/Fail} | {details} |
| Dependency relationships | {Pass/Fail} | {details} |
```

## Next Steps

Always end with relevant next steps:

1. **Scan for vulnerabilities:** `/endor-scan`
2. **Check license compliance:** `/endor-license`
3. **Generate CI/CD pipeline:** `/endor-cicd` to automate SBOM generation

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for SBOM or dependency data.** All data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external sources. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

- **Project not found**: Run `/endor-scan` first to register the project
- **Auth error**: Suggest `/endor-setup`
- **Invalid SBOM format**: Show the validation errors and suggest corrections
