---
name: endor-upgrade-impact
description: >
  Analyze the impact of upgrading a dependency before you do it. Use when the user says
  "should I upgrade lodash", "what breaks if I update express", "upgrade impact",
  "endor upgrade", "breaking changes from upgrading", or wants to find the safest
  version that fixes vulnerabilities. Uses pre-computed Endor Labs data — no scanning
  required. Do NOT use for just checking vulnerabilities (/endor-check) or applying
  a fix (/endor-fix).
---

# Endor Labs Upgrade Impact Analysis

Find safe dependency upgrades that fix vulnerabilities with minimal risk. Uses pre-computed data from the Endor Labs platform -- no scanning required.

## Workflow

### Step 1: Find Project UUID

The project UUID is often available from a prior scan. Check `.endor/scan-full-results.json` or the scan output first.

```bash
npx -y endorctl api list --resource Project -n <NAMESPACE> --filter "uuid==\"<PROJECT_UUID>\"" --field-mask="uuid,meta.name" 2>/dev/null
```

Or use `get_resource` MCP tool with `resource_type: Project` and `name: {repo_name}`.

If not found, inform the user and stop.

### Step 2: Get Best Upgrade Recommendations

Query pre-computed safe upgrades. **Do NOT run a scan.**

```bash
npx -y endorctl api list -r VersionUpgrade -n <NAMESPACE> \
  --filter="context.type==CONTEXT_TYPE_MAIN and spec.project_uuid==\"<PROJECT_UUID>\" and spec.upgrade_info.is_best==true and spec.upgrade_info.worth_it==true" \
  --field-mask="uuid,spec.name,spec.upgrade_info.is_best,spec.upgrade_info.is_latest,spec.upgrade_info.from_version,spec.upgrade_info.to_version,spec.upgrade_info.to_version_age_in_days,spec.upgrade_info.total_findings_fixed,spec.upgrade_info.total_findings_introduced,spec.upgrade_info.score_explanation,spec.upgrade_info.worth_it,spec.upgrade_info.upgrade_risk,spec.upgrade_info.direct_dependency_package" \
  --list-all 2>/dev/null
```

If user asked about a **specific package**, filter results to it. If general ("what should I upgrade?"), present all.

### Step 3: Present Results

Pick the best upgrade per package: most `total_findings_fixed` with lowest `upgrade_risk`.

```markdown
## Upgrade Impact Analysis

**Project:** {project_name}

### Recommended Upgrades

| Package | From | To | Findings Fixed | Risk | Best? | Latest? |
|---------|------|----|---------------|------|-------|---------|
| {direct_dependency_package} | {from_version} | {to_version} | {total_findings_fixed} | {upgrade_risk} | {is_best} | {is_latest} |

### {package}: {from_version} -> {to_version}

| Metric | Value |
|--------|-------|
| Findings Fixed | {total_findings_fixed} |
| Findings Introduced | {total_findings_introduced} |
| Upgrade Risk | {upgrade_risk} |
| Target Version Age | {to_version_age_in_days} days |
| Score Explanation | {score_explanation} |

### Recommendation

- **LOW risk**: Safe to upgrade.
- **MEDIUM risk**: Review changes carefully. Test thoroughly before deploying.
- **HIGH risk**: Breaking code-level changes detected. See detailed CIA below.
```

For install commands, read `references/install-commands.md`.

### Step 4: Evaluate High-Risk Upgrades (On Request Only)

Fetch CIA details only if user wants to evaluate a high-risk upgrade:

Only fetch if user asks about a HIGH risk upgrade:
```bash
npx -y endorctl api list -r VersionUpgrade -n <NAMESPACE> \
  --filter="context.type==CONTEXT_TYPE_MAIN and spec.project_uuid==\"<PROJECT_UUID>\" and uuid==\"<UUID>\"" \
  --field-mask="spec.upgrade_info.cia_results" 2>/dev/null
```

Present CIA results: API changes, removed functions, signature changes, behavioral changes. Include action items and recommendation on whether to proceed.

## Key Concepts

- **is_best** / **worth_it**: Endor Labs' recommended upgrade with best fixes-vs-risk balance
- **upgrade_risk**: LOW (auto-upgrade safe), MEDIUM (review needed), HIGH (breaking changes via call graphs)
- **cia_results**: Code-level breaking changes for high-risk upgrades (fetched on demand)

For data source policy, read `references/data-sources.md`.

## Error Handling

| Error | Action |
|-------|--------|
| License/permission error | "Upgrade Impact Analysis requires **Endor Labs OSS Pro** license. Visit [app.endorlabs.com](https://app.endorlabs.com) or contact your admin." |
| Package not in results | No recommended upgrades, or already at recommended version |
| Auth error | Follow the **Authentication Recovery** steps in `endor-safety.md` global rules |
