---
name: endor-scan-full
description: |
  Comprehensive security scan with full reachability analysis to identify exploitable vulnerabilities. Builds call graphs to determine which vulnerabilities are actually reachable in your code.
  - MANDATORY TRIGGERS: endor scan full, full scan, deep scan, reachability scan, reachability analysis, comprehensive scan, endor-scan-full
---

# Endor Labs Full Reachability Scan

Comprehensive security scan with full call graph analysis to identify exploitable vulnerabilities.

## Quick Scan vs Full Scan

| Feature | Quick Scan | Full Scan |
|---------|-----------|-----------|
| Speed | Seconds | Minutes |
| Reachability | No | Full call graph |
| Call Paths | No | Yes |
| Prioritization | Severity only | Severity + reachability |
| Use Case | Daily dev | Pre-release, security reviews |

## CRITICAL: Scan Once, Cache Always

**Cache file:** `.endor/scan-full-results.json` (relative to repo root)

Rules:
1. **Before scanning**, check if cache exists. If yes, use cached results. Do not re-scan unless user explicitly requests it ("scan again", "re-scan", "run a new scan").
2. **After successful scan**, save complete raw results to cache immediately. Create `.endor/` if needed.
3. **On scan failure**, do not write cache. Report error.
4. **For follow-up questions** about findings, read cache instead of re-scanning. If a finding UUID is missing from `finding_details`, fetch via `get_resource` and update cache.
5. **Add `.endor/` to `.gitignore`** if not already present.

### Cache Format

```json
{
  "scan_timestamp": "ISO-8601",
  "scan_path": "/absolute/path",
  "scan_types": ["vulnerabilities", "dependencies", "secrets", "sast"],
  "scan_options": { "quick_scan": false },
  "raw_results": { ... },
  "finding_details": { "uuid-1": { ... }, "uuid-2": { ... } }
}
```

## Workflow

### Step 1: Check Cache

- **Cache exists**: Show timestamp, ask user to use cached or fresh scan. If cached, skip to Step 5.
- **No cache**: Proceed with scan.

### Step 2: Detect Repository Context

Detect languages and manifest files (same as `/endor-scan`).

### Step 3: Warn About Duration

> Full reachability analysis builds a call graph of your entire codebase. This typically takes 2-5 minutes depending on project size.

### Step 4: Run Full Scan

Use `scan` MCP tool:
- `path`: **absolute path** to repository root
- `scan_types`: `["vulnerabilities", "dependencies", "secrets", "sast"]`
- `scan_options`: `{ "quick_scan": false }`

**CLI fallback** (only if MCP genuinely unavailable):
```bash
npx -y endorctl scan --path $(pwd) --output-type summary -n <namespace>
```

On error, report exact error. Do not write cache on failure.

After successful scan: save to cache, add `.endor/` to `.gitignore`, then fetch details for each finding UUID via `get_resource` (`resource_type`: `Finding`) and append to `finding_details` in cache.

### Step 5: Interpret Reachability and Present Results

For reachability tag interpretation, read references/reachability-tags.md.

#### Priority Classification

| Priority | Dependency Tag | Function Tag | Action |
|----------|---------------|--------------|--------|
| **P0 - Fix Now** | REACHABLE_DEPENDENCY | REACHABLE_FUNCTION | Actively exploitable |
| **P1 - Investigate** | REACHABLE_DEPENDENCY | POTENTIALLY_REACHABLE_FUNCTION | Likely exploitable, verify |
| **P2 - Plan Fix** | REACHABLE_DEPENDENCY | UNREACHABLE_FUNCTION | Dep used, vuln func not called |
| **P3 - Track** | UNREACHABLE_DEPENDENCY | UNREACHABLE_FUNCTION | Not used, lowest risk |
| **P4 - Ignore** | (PHANTOM) | Any | Not installed |

When dep tag present but no function tag, classify on dep tag alone (function reachability unknown).

Present: scanned path, languages, "Full Reachability Analysis", timestamp, reachability summary table with counts per category, key insight ("X of Y vulns have confirmed reachable call path"), then P0-P3 finding tables (Package, Advisory, Severity, Description).

### Next Steps

1. `/endor-fix {top-advisory}` - fix reachable critical
2. `/endor-explain {advisory}` - explain a finding
3. `/endor-findings reachable` - view all findings
4. `/endor-upgrade {package}` - upgrade with impact analysis

For data source policy, read references/data-sources.md.

## Error Handling

Never fabricate error diagnoses. Show exact error messages.

| Error | Action |
|-------|--------|
| Auth error | Complete browser login, retry. If persistent, `/endor-setup` |
| Build fails | Fix build errors first, or use `/endor-scan` (no build required) |
| Timeout | Scan specific subdirectory |
| MCP unavailable | `/endor-setup`. CLI fallback only if user confirms |
| Unknown error | Show exact error, suggest `/endor-troubleshoot` |
