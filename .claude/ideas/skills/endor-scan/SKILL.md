---
name: endor-scan
description: |
  Perform a fast security scan of the current repository using Endor Labs. Identifies vulnerabilities, license issues, and secrets without full reachability analysis.
  - MANDATORY TRIGGERS: endor scan, quick scan, security scan, scan repo, scan repository, scan my code, endor-scan
---

# Endor Labs Quick Scan

Perform a fast security scan of the current repository.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)
- Current directory is a repository with source code

## Workflow

### Step 1: Run Scan via CLI

Use `--output-type summary` for display and parse the summary counts from the CLI stderr/stdout. Do NOT use `--output-type json` for the initial scan — it produces massive output that wastes tokens.

**Detect the absolute path** to the current working directory first.

**Full repository scan (default):**

```bash
endorctl scan --path <ABSOLUTE_PATH> --quick-scan --dependencies --sast --secrets --output-type summary 2>&1
```

**Incremental PR scan** (when user mentions "PR", "pull request", "just my changes", or is on a feature branch):

```bash
endorctl scan --path <ABSOLUTE_PATH> --pr --dependencies --sast --secrets --output-type summary 2>&1
```

If `endorctl` is not found, try `npx -y endorctl` instead. If that also fails, suggest `/endor-setup`.

**IMPORTANT:** Always include `--sast` and `--secrets` flags explicitly.

### Step 2: Extract Findings Efficiently

After the summary scan completes, run a **targeted JSON query** to get only critical/high findings with the fields you need. Do NOT dump all findings as JSON.

```bash
endorctl scan --path <ABSOLUTE_PATH> --quick-scan --dependencies --sast --secrets --output-type json 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
findings = data.get('all_findings', [])
for f in findings:
    s = f.get('spec', {})
    m = f.get('meta', {})
    level = s.get('level', '')
    if 'CRITICAL' not in level and 'HIGH' not in level:
        continue
    tags = s.get('finding_tags', [])
    desc = m.get('description', '')[:120]
    remediation = s.get('remediation', '')[:120]
    proposed = s.get('proposed_version', '')
    fix = 'FINDING_TAGS_FIX_AVAILABLE' in tags
    direct = 'FINDING_TAGS_DIRECT' in tags
    print(f'{level}|{desc}|{remediation}|fix={fix}|direct={direct}|proposed={proposed}')
"
```

**CRITICAL: The CLI JSON output structure is `{ "all_findings": [...], "blocking_findings": [...], "warning_findings": [...] }`. Each finding has `spec` and `meta` keys. Do NOT guess the structure — use `all_findings` directly.**

If the JSON pipe fails (encoding errors on Windows), add `encoding='utf-8'` to file reads, or redirect to a temp file first:

```bash
endorctl scan ... --output-type json 2>/dev/null > /tmp/endor-scan.json
python3 -c "
import json
with open('/tmp/endor-scan.json', encoding='utf-8') as f:
    data = json.load(f)
# ... same parsing as above
"
```

### Step 3: Present Results

```markdown
## Security Scan Complete

**Path:** {scanned path}
**Scan Mode:** {Quick / Incremental PR}

### Vulnerability Summary

| Severity | Count | Action |
|----------|-------|--------|
| Critical | {n} | Fix immediately |
| High | {n} | Fix urgently |
| Medium | {n} | Plan remediation |
| Low | {n} | Track as debt |

### Top Critical/High Findings

| # | Package | Advisory | Severity | Fix Available | Description |
|---|---------|----------|----------|---------------|-------------|
| 1 | {pkg} | {advisory} | Critical | Yes/No | {desc} |

### Next Steps

1. `/endor-fix {top-advisory}` — Fix critical issues
2. `/endor-scan-full` — Full reachability analysis
3. `/endor-explain {advisory}` — Vulnerability details
```

### Reachability Tags Reference

Reachability is on two dimensions in `finding_tags`:
- **Dependency:** `FINDING_TAGS_REACHABLE_DEPENDENCY` / `UNREACHABLE_DEPENDENCY`
- **Function:** `FINDING_TAGS_REACHABLE_FUNCTION` / `UNREACHABLE_FUNCTION` / `POTENTIALLY_REACHABLE_FUNCTION`
- **Other:** `FINDING_TAGS_PHANTOM`, `FINDING_TAGS_DIRECT`, `FINDING_TAGS_TRANSITIVE`, `FINDING_TAGS_FIX_AVAILABLE`, `FINDING_TAGS_UNFIXABLE`

### MCP Tool Fallback

If an MCP `scan` tool is available, prefer it over CLI. Use parameters:
- `path`: absolute path
- `scan_types`: `["vulnerabilities", "dependencies", "sast", "secrets"]`
- `scan_options`: `{ "quick_scan": true }`

Only fall back to CLI if MCP is unavailable. Do NOT invent error diagnoses — show exact errors and suggest `/endor-troubleshoot`.

## Data Sources — Endor Labs Only

**NEVER use external websites for vulnerability information.** All data must come from Endor Labs tools. If unavailable, suggest [app.endorlabs.com](https://app.endorlabs.com).
