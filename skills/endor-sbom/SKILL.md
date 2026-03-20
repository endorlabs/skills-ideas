---
name: endor-sbom
description: >
  Manage Software Bill of Materials — export, import, analyze, and compare SBOMs in
  CycloneDX and SPDX formats. Use when the user says "generate SBOM", "export SBOM",
  "software bill of materials", "endor sbom", "compare SBOMs", "NTIA compliance", or
  needs component inventory for compliance. Do NOT use for vulnerability scanning
  (/endor-scan) or license analysis (/endor-license).
---

# Endor Labs SBOM Management

Manage Software Bill of Materials - export, import, analyze, and compare.

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

1. Use `get_resource` MCP tool (`resource_type`: `Project`, `name`: project/repo name) to get UUID. If not found, suggest `/endor-scan` first.
2. Export SBOM:
```bash
# CycloneDX (recommended)
npx -y endorctl sbom export --project-uuid {uuid} --format cyclonedx --output sbom-cyclonedx.json

# SPDX
npx -y endorctl sbom export --project-uuid {uuid} --format spdx --output sbom-spdx.json
```
3. Present summary with: format, file path, project name, component counts by type (Libraries/Frameworks/Applications/Total), top-level dependencies with versions and licenses, NTIA compliance checks (component names, versions, unique IDs, dependency relationships, author info, timestamp).

### Action: Analyze

1. Run `/endor-scan` if not already scanned
2. Query findings and dependencies
3. Present component breakdown:
   - Counts by category (direct/transitive/dev) with vuln and license risk counts
   - Vulnerability coverage: components with CVEs, critical/high count, reachable count
   - License distribution with risk levels

### Action: Compare

Compare two SBOMs for drift detection. Present:
- Added/removed/updated packages with versions
- Security impact: new vulns introduced, vulns resolved, net change
- License impact: new risks, resolved risks

### Action: Validate

Validate SBOM file against compliance standards. Check: format validity, NTIA minimum elements, component completeness, dependency relationships.

## Next Steps

1. `/endor-scan` - scan for vulnerabilities
2. `/endor-license` - check license compliance
3. `/endor-cicd` - automate SBOM generation

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| Project not found | Run `/endor-scan` first |
| Auth error | Run `/endor-setup` |
| Invalid SBOM format | Show validation errors, suggest corrections |
