---
name: endor-score
description: |
  View Endor Labs health scores for open source packages. Evaluates activity, popularity, security, and quality to help you choose safe dependencies.
  - MANDATORY TRIGGERS: endor score, package score, package health, should I use, evaluate package, endor-score, is this package safe, package quality
---

# Endor Labs Package Score

Evaluate open source package health before adoption using Endor Labs scoring.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)

## Input Parsing

Parse the user's input to extract:

1. **Package name** (required) - e.g., `lodash`, `express`, `django`
2. **Version** (optional) - specific version to evaluate
3. **Compare with** (optional) - another package for comparison

## Workflow

### Step 1: Get Package Vulnerability Information

First, check the package for vulnerabilities using the `check_dependency_for_vulnerabilities` MCP tool:
- `ecosystem`: Package ecosystem (npm, python, go, java, maven)
- `dependency_name`: Package name
- `version`: Version to evaluate

### Step 2: Get Package Metrics via CLI

Use the CLI to query package metrics from the OSS namespace:

```bash
# Get package version info (always redirect stderr when piping to JSON parser)
npx -y endorctl api list --resource PackageVersion -n oss --filter "meta.name=={ecosystem}://{package}@{version}" 2>/dev/null

# Get package scorecard (use the package UUID from the previous command)
npx -y endorctl api list --resource Metric -n oss --filter "meta.name==package_version_scorecard and meta.parent_uuid=={package_uuid}" 2>/dev/null
```

Alternatively, use the `get_resource` MCP tool:
- `name`: `{ecosystem}://{package}@{version}`
- `resource_type`: `PackageVersion`

Then get metrics:
- `resource_type`: `Metric`
- `name`: `package_version_scorecard` (with the package UUID as parent)

### Step 3: Present Scores

```markdown
## Package Health: {package}@{version}

### Overall Score: {score}/10

| Category | Score | Details |
|----------|-------|---------|
| Activity | {n}/10 | {commit frequency, last release, contributor count} |
| Popularity | {n}/10 | {downloads, stars, dependents} |
| Security | {n}/10 | {CVE count, security practices, OSSF scorecard} |
| Quality | {n}/10 | {tests, docs, type support} |

### Score Breakdown

#### Activity ({score}/10)
- Last commit: {date}
- Release frequency: {cadence}
- Active contributors: {count}
- Issue response time: {time}

#### Popularity ({score}/10)
- Weekly downloads: {count}
- GitHub stars: {count}
- Dependent packages: {count}

#### Security ({score}/10)
- Known CVEs: {count} ({critical}, {high}, {medium}, {low})
- OpenSSF Scorecard: {score}
- Signed releases: {yes/no}
- Security policy: {yes/no}

#### Quality ({score}/10)
- Test coverage: {available/not available}
- Documentation: {quality}
- TypeScript types: {bundled/DefinitelyTyped/none}
- License: {license}

### Vulnerability History

| CVE | Severity | Fixed In | Date |
|-----|----------|----------|------|
| {cve} | {severity} | {version} | {date} |

### Recommendation

{Based on scores:}

- **Score >= 8**: Recommended for production use
- **Score 6-7**: Acceptable, monitor for issues
- **Score 4-5**: Use with caution, consider alternatives
- **Score < 4**: Not recommended, find alternatives
```

### Step 4: Version Comparison (if requested)

If the user asks to compare versions:

```markdown
### Version Comparison

| Metric | {v1} | {v2} |
|--------|------|------|
| CVEs | {n} | {n} |
| Score | {n}/10 | {n}/10 |
| Release Date | {date} | {date} |
```

### Step 5: Package Comparison (if requested)

If the user asks to compare packages:

```markdown
### Package Comparison: {pkg1} vs {pkg2}

| Metric | {pkg1} | {pkg2} |
|--------|--------|--------|
| Overall Score | {n}/10 | {n}/10 |
| Activity | {n}/10 | {n}/10 |
| Popularity | {n}/10 | {n}/10 |
| Security | {n}/10 | {n}/10 |
| Quality | {n}/10 | {n}/10 |
| Known CVEs | {n} | {n} |
| License | {lic} | {lic} |

**Recommendation:** {which package is better and why}
```

## Next Steps

Always end with:

1. **Check vulnerabilities:** `/endor-check {package}`
2. **Upgrade analysis:** `/endor-upgrade {package}`
3. **Full scan:** `/endor-scan` to see impact on your project

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for package scores, health metrics, or popularity data.** All data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web, visit npmjs.com, pypi.org, GitHub, or any other external source. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

- **Package not found**: Check the package name and ecosystem. The OSS namespace may not have indexed the package yet. Do NOT look up the package on external websites.
- **Metrics not available**: The package may be too new or too small for scoring.
- **Auth error**: Suggest `/endor-setup`
