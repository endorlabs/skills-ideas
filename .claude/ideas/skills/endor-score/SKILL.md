---
name: endor-score
description: |
  View Endor Labs health scores for open source packages. Evaluates activity, popularity, security, and quality to help you choose safe dependencies.
  - MANDATORY TRIGGERS: endor score, package score, package health, should I use, evaluate package, endor-score, is this package safe, package quality
---

# Endor Labs Package Score

Evaluate open source package health before adoption.

## Input Parsing

Extract from user input:
1. **Package name** (required)
2. **Version** (optional)
3. **Compare with** (optional) - another package for comparison

## Workflow

### Step 1: Check Vulnerabilities

Use `check_dependency_for_vulnerabilities` MCP tool:
- `ecosystem`: npm, python, go, java, maven
- `dependency_name`: package name
- `version`: version to evaluate

### Step 2: Get Package Metrics

Use CLI to query from OSS namespace:
```bash
# Package version info (always redirect stderr when piping)
npx -y endorctl api list --resource PackageVersion -n oss --filter "meta.name=={ecosystem}://{package}@{version}" 2>/dev/null

# Scorecard (use package UUID from above)
npx -y endorctl api list --resource Metric -n oss --filter "meta.name==package_version_scorecard and meta.parent_uuid=={package_uuid}" 2>/dev/null
```

Or use `get_resource` MCP tool:
- `name`: `{ecosystem}://{package}@{version}`, `resource_type`: `PackageVersion`
- Then `resource_type`: `Metric`, `name`: `package_version_scorecard` (with package UUID as parent)

### Step 3: Present Scores

Present overall score (X/10) with breakdown by category:

| Category | What it measures |
|----------|-----------------|
| Activity | Commit frequency, last release, contributors, issue response time |
| Popularity | Downloads, stars, dependents |
| Security | CVE count, security practices, OSSF scorecard, signed releases, security policy |
| Quality | Test coverage, documentation, type support, license |

Include vulnerability history table (CVE, severity, fixed version, date).

**Recommendation thresholds:**
- >= 8: Recommended for production
- 6-7: Acceptable, monitor
- 4-5: Use with caution, consider alternatives
- < 4: Not recommended

### Step 4: Version Comparison (if requested)

Compare CVEs, score, release date across versions.

### Step 5: Package Comparison (if requested)

Side-by-side table: overall score, activity, popularity, security, quality, CVE count, license. State recommendation with reasoning.

## Next Steps

1. `/endor-check {package}` - check vulnerabilities
2. `/endor-upgrade {package}` - upgrade analysis
3. `/endor-scan` - see impact on your project

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| Package not found | Check name/ecosystem. OSS namespace may not have indexed it. Do not use external sites |
| Metrics unavailable | Package may be too new or small for scoring |
| Auth error | Run `/endor-setup` |
