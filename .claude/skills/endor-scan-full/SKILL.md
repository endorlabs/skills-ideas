---
name: endor-scan-full
description: |
  Comprehensive security scan with full reachability analysis to identify exploitable vulnerabilities. Builds call graphs to determine which vulnerabilities are actually reachable in your code.
  - MANDATORY TRIGGERS: endor scan full, full scan, deep scan, reachability scan, reachability analysis, comprehensive scan, endor-scan-full
---

# Endor Labs Full Reachability Scan

Perform a comprehensive security scan with full call graph analysis. This identifies which vulnerabilities are actually reachable (exploitable) in your code.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)
- Current directory is a repository with source code
- Build tools installed for the project language

## What Makes This Different from Quick Scan

| Feature | Quick Scan | Full Scan |
|---------|-----------|-----------|
| Speed | Seconds | Minutes |
| Reachability | No | Full call graph |
| Call Paths | No | Yes - see how vulnerable code is reached |
| Prioritization | By severity only | By severity + reachability |
| Use Case | Daily development | Pre-release audits, security reviews |

## CRITICAL: Scan Once, Reference Always

**The scan MUST only run ONE time.** After a successful scan, all results are saved to a local cache file. For any subsequent questions, lookups, or analysis of scan results, ALWAYS read the cached file instead of running a new scan.

**Cache file location:** `.endor/scan-full-results.json` (relative to the repository root)

### Rules

1. **Before scanning**, check if `.endor/scan-full-results.json` already exists. If it does, read it and use those results — do NOT re-scan unless the user explicitly asks to re-scan (e.g., "scan again", "re-scan", "run a new scan").
2. **After a successful scan**, immediately save the complete raw scan results (the full MCP tool response) to `.endor/scan-full-results.json`. Create the `.endor/` directory if it doesn't exist.
3. **If the scan fails** (MCP tool returns an error or non-zero exit), do NOT write to the cache file. Report the error to the user.
4. **For all follow-up questions** about findings, severities, packages, call paths, reachability, or anything related to the scan — read `.endor/scan-full-results.json` instead of running another scan.
5. **Add `.endor/` to `.gitignore`** if it's not already there, so cached results are not committed.

### Cache file format

Write the results as a JSON object:

```json
{
  "scan_timestamp": "ISO-8601 timestamp of when the scan was run",
  "scan_path": "/absolute/path/that/was/scanned",
  "scan_types": ["vulnerabilities", "dependencies", "secrets", "sast"],
  "scan_options": { "quick_scan": false },
  "raw_results": { ... the complete MCP tool response ... },
  "finding_details": {
    "finding-uuid-1": { ... full finding detail from get_resource ... },
    "finding-uuid-2": { ... }
  }
}
```

The `finding_details` map is populated in Step 5 as you retrieve details for each finding. This way, individual finding details are also cached and never need to be re-fetched.

## Workflow

### Step 1: Check for Cached Results

Before doing anything else, check if `.endor/scan-full-results.json` exists:

- **If the file exists**: Read it and tell the user that cached scan results were found (include the timestamp). Ask if they want to use the cached results or run a fresh scan. If they want cached results, skip directly to Step 6 (Present Results) using the cached data.
- **If the file does not exist**: Proceed with the scan.

### Step 2: Detect Repository Context

Same as `/endor-scan` - detect languages and manifest files.

### Step 3: Warn About Duration

Tell the user:

> Full reachability analysis builds a call graph of your entire codebase. This typically takes 2-5 minutes depending on project size. I'll keep you updated on progress.

### Step 4: Run Full Scan

Use the `scan` MCP tool with these parameters:

- `path`: The **absolute path** to the repository root (required - must be fully qualified)
- `scan_types`: `["vulnerabilities", "dependencies", "secrets", "sast"]`
- `scan_options`: `{ "quick_scan": false }` (disabling quick_scan enables full reachability analysis)

If the MCP tool returns an error, **report the exact error to the user first** — do NOT guess or fabricate the cause. Do NOT save anything to the cache file on failure. Only fall back to CLI if the MCP server is genuinely unavailable (not configured or not installed):

```bash
npx -y endorctl scan --path $(pwd) --output-type summary -n <namespace>
```

### Step 5: Save Results and Retrieve Finding Details

**Immediately after a successful scan:**

1. Create the `.endor/` directory if it doesn't exist.
2. Save the complete scan results to `.endor/scan-full-results.json` (see format above).
3. Ensure `.endor/` is in `.gitignore`.
4. For each finding UUID returned by the scan, use the `get_resource` MCP tool to retrieve full details:
   - `uuid`: The finding UUID
   - `resource_type`: `Finding`
5. **Append each finding's details** to the `finding_details` map in the cache file so they are available for future reference without additional API calls.
6. After all finding details are retrieved, write the final updated cache file.

The finding data includes reachability information and call paths when available.

### Step 6: Interpret Reachability Tags and Present Results

Format results emphasizing reachability. Use data from the cache file (whether just-scanned or previously cached).

**IMPORTANT: Endor Labs does NOT use simple `FINDING_TAGS_REACHABLE` / `FINDING_TAGS_UNREACHABLE` tags.** Reachability is expressed on **two separate dimensions** in the `finding_tags` array:

#### Dependency Reachability (is the vulnerable package imported/used by your code?)
- `FINDING_TAGS_REACHABLE_DEPENDENCY` — your code imports/uses this dependency
- `FINDING_TAGS_UNREACHABLE_DEPENDENCY` — your code does NOT import/use this dependency

#### Function Reachability (is the specific vulnerable function called?)
- `FINDING_TAGS_REACHABLE_FUNCTION` — a call path exists from your code to the vulnerable function
- `FINDING_TAGS_UNREACHABLE_FUNCTION` — no call path reaches the vulnerable function
- `FINDING_TAGS_POTENTIALLY_REACHABLE_FUNCTION` — a call path may exist but could not be fully confirmed

#### Other Relevant Tags
- `FINDING_TAGS_PHANTOM` — dependency appears in lockfile but is not actually installed/used
- `FINDING_TAGS_DIRECT` — vulnerability is in a direct dependency
- `FINDING_TAGS_TRANSITIVE` — vulnerability is in a transitive dependency
- `FINDING_TAGS_FIX_AVAILABLE` — an upgrade path exists
- `FINDING_TAGS_UNFIXABLE` — no known fix available

#### Priority Classification

Classify each finding by combining both dimensions:

| Priority | Dependency Tag | Function Tag | Action |
|----------|---------------|--------------|--------|
| **P0 - Fix Now** | REACHABLE_DEPENDENCY | REACHABLE_FUNCTION | Actively exploitable in your code |
| **P1 - Investigate** | REACHABLE_DEPENDENCY | POTENTIALLY_REACHABLE_FUNCTION | Likely exploitable, verify call path |
| **P2 - Plan Fix** | REACHABLE_DEPENDENCY | UNREACHABLE_FUNCTION | Dependency used but vuln function not called |
| **P3 - Track** | UNREACHABLE_DEPENDENCY | UNREACHABLE_FUNCTION | Not used by your code, lowest risk |
| **P4 - Ignore** | (PHANTOM tag present) | Any | Not actually installed |

When a finding has a dependency tag but no function tag, classify based on the dependency tag alone (treat function reachability as unknown).

#### Presenting Results

```markdown
## Full Security Scan Complete

**Path:** {scanned path}
**Languages:** {detected languages}
**Scan Type:** Full Reachability Analysis
**Scanned At:** {timestamp from cache}

### Reachability Summary

| Category | Count | Description |
|----------|-------|-------------|
| Reachable Dep + Reachable Function | {n} | Exploitable — fix immediately |
| Reachable Dep + Potentially Reachable Function | {n} | Likely exploitable — investigate |
| Reachable Dep + Unreachable Function | {n} | Dep used, vuln function not called |
| Unreachable Dep + Unreachable Function | {n} | Not used by your code |
| Phantom | {n} | Not actually installed |

> **Key Insight:** {P0_count} of {total_count} vulnerabilities have a confirmed reachable call path to the vulnerable function. Focus remediation on these first.

### P0 — Reachable Function (Fix Now)

| # | Package | Advisory | Severity | Description |
|---|---------|----------|----------|-------------|
| 1 | {pkg} | {advisory} | {severity} | {desc} |

### P1 — Potentially Reachable (Investigate)

| # | Package | Advisory | Severity | Description |
|---|---------|----------|----------|-------------|
| 1 | {pkg} | {advisory} | {severity} | {desc} |

### P2 — Reachable Dependency, Unreachable Function (Plan Fix)

| # | Package | Advisory | Severity | Description |
|---|---------|----------|----------|-------------|
| 1 | {pkg} | {advisory} | {severity} | {desc} |

### P3 — Unreachable (Track)

{count} vulnerabilities are in dependencies not imported by your code. Lowest risk but track for hygiene.

### Next Steps

1. **Fix reachable critical:** `/endor-fix {top-advisory}`
2. **Explain a finding:** `/endor-explain {advisory}`
3. **View all findings:** `/endor-findings reachable`
4. **Upgrade with impact analysis:** `/endor-upgrade {package}`
```

## Answering Follow-Up Questions

When the user asks follow-up questions about scan results (e.g., "what are the critical findings?", "show me the call path for CVE-X", "which packages are affected?"):

1. **Read `.endor/scan-full-results.json`** — do NOT run a new scan.
2. Parse the cached data to answer the question.
3. If a specific finding UUID's details are not in the `finding_details` map, use `get_resource` to fetch it, then **update the cache file** with the new details so it doesn't need to be fetched again.

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for vulnerability or security information.** All data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external vulnerability databases. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

**CRITICAL: Always report exact error messages to the user. Never fabricate, guess, or invent error diagnoses.**

- **Auth error**: Tell user to complete browser login, then retry. Do NOT bypass by switching to CLI. If persistent, suggest `/endor-setup`.
- **Build fails**: The full scan may need the project to be buildable. Suggest fixing build errors first, or use `/endor-scan` for a quick scan that doesn't require building.
- **Timeout**: Large monorepos may take longer. Suggest scanning a specific subdirectory.
- **MCP not available**: Suggest `/endor-setup`. Only fall back to CLI if the user confirms MCP cannot be configured.
- **Unknown error**: Show the exact error text to the user. Suggest `/endor-troubleshoot`. Do NOT guess the cause.
