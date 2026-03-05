---
name: endor-upgrade-impact
description: |
  Analyze the impact of upgrading a dependency before you do it. Uses Endor Labs' Upgrade Impact Analysis to find safe versions that fix vulnerabilities with minimal breaking changes.
  - MANDATORY TRIGGERS: endor upgrade, upgrade impact, breaking changes, change impact, dependency upgrade, upgrade analysis, endor-upgrade, should I upgrade, impact of upgrading
---

# Endor Labs Upgrade Impact Analysis

Find safe dependency upgrades with minimal risk. Uses pre-computed data — no scanning required.

## Workflow

### Step 1: Find Project UUID

The project UUID is often available from a prior scan. Check `.endor/scan-full-results.json` or the scan output first.

If not available, look it up. **IMPORTANT:** The project name in Endor Labs is typically the full git clone URL (e.g., `https://github.com/org/repo.git`), not just the repo name. Use the UUID from prior scan output if available — it was printed in the scan's INFO lines as `Scanning Project UUID: <uuid>`.

If you must query:
```bash
endorctl api list --resource Project -n <NAMESPACE> --filter "uuid==\"<PROJECT_UUID>\"" --field-mask="uuid,meta.name" 2>/dev/null
```

### Step 2: Get Best Upgrade Recommendations

Query all recommended upgrades in a **single call**:

```bash
endorctl api list -r VersionUpgrade -n <NAMESPACE> \
  --filter="context.type==CONTEXT_TYPE_MAIN and spec.project_uuid==\"<PROJECT_UUID>\" and spec.upgrade_info.is_best==true and spec.upgrade_info.worth_it==true" \
  --field-mask="uuid,spec.name,spec.upgrade_info.is_best,spec.upgrade_info.is_latest,spec.upgrade_info.from_version,spec.upgrade_info.to_version,spec.upgrade_info.to_version_age_in_days,spec.upgrade_info.total_findings_fixed,spec.upgrade_info.total_findings_introduced,spec.upgrade_info.score_explanation,spec.upgrade_info.worth_it,spec.upgrade_info.upgrade_risk,spec.upgrade_info.direct_dependency_package" \
  --list-all 2>/dev/null
```

**Pipe through Python to extract only what's needed** — do NOT dump raw API JSON into context:

```bash
... | python3 -c "
import json, sys
data = json.load(sys.stdin)
seen = set()
for o in data.get('list', {}).get('objects', []):
    ui = o['spec']['upgrade_info']
    pkg = ui.get('direct_dependency_package', '')
    key = f\"{pkg}|{ui.get('from_version')}|{ui.get('to_version')}\"
    if key in seen: continue
    seen.add(key)
    print(f\"{pkg}|{ui['from_version']}|{ui['to_version']}|fixed={ui['total_findings_fixed']}|introduced={ui.get('total_findings_introduced',0)}|risk={ui['upgrade_risk']}|best={ui['is_best']}|{ui.get('score_explanation','')}\" )
"
```

### Step 3: Present Results

```markdown
## Upgrade Impact Analysis

| Package | From | To | Fixed | Introduced | Risk | Breaking Changes? |
|---------|------|----|-------|------------|------|-------------------|
| {pkg} | {from} | {to} | {fixed} | {introduced} | {risk} | {explanation} |

### Recommendation
- **LOW risk**: Safe to upgrade
- **MEDIUM risk**: No breaking changes detected, but review and test
- **HIGH risk**: Breaking code-level changes detected — run Step 4
```

### Step 4: High-Risk CIA Details (On Request Only)

Only fetch if user asks about a HIGH risk upgrade:
```bash
endorctl api list -r VersionUpgrade -n <NAMESPACE> \
  --filter="context.type==CONTEXT_TYPE_MAIN and spec.project_uuid==\"<PROJECT_UUID>\" and uuid==\"<UUID>\"" \
  --field-mask="spec.upgrade_info.cia_results" 2>/dev/null
```

## Key Concepts

- **is_best**: Best balance of fixes vs. risk
- **upgrade_risk**: LOW (auto-upgrade safe), MEDIUM (review needed), HIGH (breaking changes via call graphs)
- **total_findings_fixed/introduced**: Vulns resolved/added by upgrading

## Error Handling

- **License error**: Upgrade Impact requires Endor Labs OSS Pro license
- **Package not in results**: No recommended upgrades exist, or already at recommended version
- **Auth error**: Suggest `/endor-setup`

## Data Sources — Endor Labs Only

**NEVER use external websites.** All data must come from Endor Labs API/CLI. If unavailable, suggest [app.endorlabs.com](https://app.endorlabs.com).
