---
name: endor-scan-full
description: |
  Comprehensive security scan with full reachability analysis to identify exploitable vulnerabilities. Builds call graphs to determine which vulnerabilities are actually reachable in your code.
  - MANDATORY TRIGGERS: endor scan full, full scan, deep scan, reachability scan, reachability analysis, comprehensive scan, endor-scan-full
---

# Endor Labs Full Reachability Scan

Full call graph analysis to identify which vulnerabilities are actually reachable (exploitable).

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not), or `endorctl` CLI installed
- Build tools installed for the project language

## CRITICAL: Scan Once, Reference Always

**Cache file:** `.endor/scan-full-results.json`

1. **Before scanning**, check if cache exists. If yes, use it (skip to presenting results) unless user explicitly asks to re-scan.
2. **After scan**, save parsed results (NOT raw JSON) to cache.
3. **Add `.endor/` to `.gitignore`**.

## Workflow

### Step 1: Check Cache

Check if `.endor/scan-full-results.json` exists. If yes, read and present cached results with timestamp.

### Step 2: Run Full Scan

Use `--output-type summary` first for the user-visible progress, then extract JSON to a temp file:

```bash
endorctl scan --path <ABSOLUTE_PATH> --dependencies --sast --secrets --output-type json 2>/dev/null > /tmp/endor-full.json
```

If `endorctl` not found, try `npx -y endorctl`. If MCP `scan` tool is available, use it with `scan_options: { "quick_scan": false }`.

**CRITICAL: The CLI JSON structure is `{ "all_findings": [...], "blocking_findings": [...], "warning_findings": [...] }`. Each finding has `spec` and `meta` keys.**

### Step 3: Parse and Cache in ONE Python Call

Do all parsing, classification, and caching in a single Python script. Do NOT make multiple passes over the data.

```bash
python3 -c "
import json, datetime

with open('/tmp/endor-full.json', encoding='utf-8') as f:
    data = json.load(f)

findings = data.get('all_findings', [])
p0, p1, p2, p3, p4 = [], [], [], [], []
counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}

for f in findings:
    s = f.get('spec', {})
    m = f.get('meta', {})
    tags = s.get('finding_tags', [])
    level = s.get('level', '')
    desc = m.get('description', '')[:120]
    remediation = s.get('remediation', '')[:150]
    proposed = s.get('proposed_version', '')
    fix = 'FINDING_TAGS_FIX_AVAILABLE' in tags
    direct = 'FINDING_TAGS_DIRECT' in tags
    eco = s.get('ecosystem', '')

    if 'CRITICAL' in level: counts['critical'] += 1
    elif 'HIGH' in level: counts['high'] += 1
    elif 'MEDIUM' in level: counts['medium'] += 1
    elif 'LOW' in level: counts['low'] += 1

    entry = {'desc': desc, 'level': level, 'fix': fix, 'direct': direct,
             'proposed': proposed, 'remediation': remediation, 'eco': eco,
             'tags': [t for t in tags if 'REACHABLE' in t or t in (
                 'FINDING_TAGS_DIRECT','FINDING_TAGS_TRANSITIVE',
                 'FINDING_TAGS_FIX_AVAILABLE','FINDING_TAGS_UNFIXABLE','FINDING_TAGS_PHANTOM')]}

    if 'FINDING_TAGS_PHANTOM' in tags:
        p4.append(entry)
    elif 'FINDING_TAGS_REACHABLE_DEPENDENCY' in tags and 'FINDING_TAGS_REACHABLE_FUNCTION' in tags:
        p0.append(entry)
    elif ('FINDING_TAGS_REACHABLE_DEPENDENCY' in tags or 'FINDING_TAGS_POTENTIALLY_REACHABLE_DEPENDENCY' in tags) and \
         ('FINDING_TAGS_REACHABLE_FUNCTION' in tags or 'FINDING_TAGS_POTENTIALLY_REACHABLE_FUNCTION' in tags):
        p1.append(entry)
    elif 'FINDING_TAGS_REACHABLE_DEPENDENCY' in tags and 'FINDING_TAGS_UNREACHABLE_FUNCTION' in tags:
        p2.append(entry)
    elif 'FINDING_TAGS_POTENTIALLY_REACHABLE_DEPENDENCY' in tags:
        p2.append(entry)
    else:
        p3.append(entry)

sev = lambda x: 0 if 'CRITICAL' in x['level'] else 1 if 'HIGH' in x['level'] else 2 if 'MEDIUM' in x['level'] else 3
for lst in [p0, p1, p2]: lst.sort(key=sev)

result = {
    'scan_timestamp': datetime.datetime.now().isoformat(),
    'scan_path': '<ABSOLUTE_PATH>',
    'counts': counts, 'total': len(findings),
    'p0': p0, 'p1': p1, 'p2': p2[:15],
    'p3_count': len(p3), 'p4_count': len(p4)
}

import os
os.makedirs('<REPO_ROOT>/.endor', exist_ok=True)
with open('<REPO_ROOT>/.endor/scan-full-results.json', 'w', encoding='utf-8') as f:
    json.dump(result, f)

print(json.dumps(result, indent=2))
"
```

**This single script does everything:** reads JSON, classifies by reachability, sorts by severity, caches to disk, and outputs the parsed summary. No re-reading, no multiple passes.

### Step 4: Present Results

```markdown
## Full Security Scan Complete

**Path:** {path} | **Scan Type:** Full Reachability Analysis

### Reachability Summary

| Category | Count | Description |
|----------|-------|-------------|
| P0 — Reachable Function | {n} | Exploitable — fix now |
| P1 — Potentially Reachable | {n} | Likely exploitable — investigate |
| P2 — Unreachable Function | {n} | Dep used, vuln function not called |
| P3 — Unreachable | {n} | Not used by your code |

### P0 — Fix Now
| Package | Advisory | Severity | Fix Version |
|---------|----------|----------|-------------|
| {from remediation} | {from desc} | {level} | {proposed} |

### Next Steps
1. `/endor-fix {advisory}` — Fix reachable issues
2. `/endor-upgrade {package}` — Check upgrade impact
3. `/endor-explain {advisory}` — Vulnerability details
```

### Reachability Tags Reference

- **Dependency:** `REACHABLE_DEPENDENCY` / `UNREACHABLE_DEPENDENCY` / `POTENTIALLY_REACHABLE_DEPENDENCY`
- **Function:** `REACHABLE_FUNCTION` / `UNREACHABLE_FUNCTION` / `POTENTIALLY_REACHABLE_FUNCTION`
- **P0:** Reachable dep + Reachable function (exploitable)
- **P1:** Reachable/potentially reachable dep + potentially reachable function
- **P2:** Reachable dep + unreachable function
- **P3:** Unreachable dep (lowest risk)
- **P4:** PHANTOM (not installed)

## Data Sources — Endor Labs Only

**NEVER use external websites for vulnerability information.** All data must come from Endor Labs tools. If unavailable, suggest [app.endorlabs.com](https://app.endorlabs.com).
