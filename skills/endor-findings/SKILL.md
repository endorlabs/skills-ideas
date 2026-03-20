---
name: endor-findings
description: >
  Display and filter security findings from Endor Labs. Use when the user says "show
  findings", "list vulnerabilities", "what did the scan find", "endor findings",
  "show me critical reachable vulns", or wants to browse/filter results after a scan.
  Supports filtering by severity, reachability, category (vuln/sast/secrets/license).
  Do NOT use for running a new scan (/endor-scan) or explaining a specific CVE
  (/endor-explain).
---

# Endor Labs Findings Viewer

Query and display security findings with filtering support.

## Filter Reference

Parse user input to build filters:

| User Says | API Filter |
|-----------|-----------|
| `critical` | `spec.level==FINDING_LEVEL_CRITICAL` |
| `high` | `spec.level==FINDING_LEVEL_HIGH` |
| `medium` | `spec.level==FINDING_LEVEL_MEDIUM` |
| `low` | `spec.level==FINDING_LEVEL_LOW` |
| `reachable` | `spec.finding_tags contains FINDING_TAGS_REACHABLE_FUNCTION` |
| `unreachable` | `spec.finding_tags not contains FINDING_TAGS_REACHABLE_FUNCTION` |
| `vulnerability`, `vuln` | `spec.finding_categories contains FINDING_CATEGORY_VULNERABILITY` |
| `sast` | `spec.finding_categories contains FINDING_CATEGORY_SAST` |
| `secrets`, `secret` | `spec.finding_categories contains FINDING_CATEGORY_SECRETS` |
| `license` | `spec.finding_categories contains FINDING_CATEGORY_LICENSE_RISK` |
| `no-test` | `spec.finding_tags not contains FINDING_TAGS_TEST_DEPENDENCY` |

Combine multiple filters with `and`. Default (no user filters): critical + high, excluding test dependencies.

## Workflow

### Step 1: Query Findings

**Option A — After a scan:** `scan` MCP tool returns finding UUIDs sorted by severity. Use `get_resource` (resource_type: `Finding`) for each UUID.

**Option B — From platform:** Run `/endor-scan` first, then retrieve findings via `get_resource`.

**Option C — CLI fallback:**
```bash
npx -y endorctl api list --resource Finding -n $ENDOR_NAMESPACE --filter "{filter_string}" 2>/dev/null
```

For CLI field paths and parsing gotchas, read references/cli-parsing.md.

### Step 2: Interpret Reachability

For reachability tag interpretation, read references/reachability-tags.md.

### Step 3: Present Results

```markdown
## Security Findings

**Filter:** {human-readable filter description}
**Total:** {count} findings

### Findings

| # | Severity | Category | Package | CVE/Issue | Reachability | Description |
|---|----------|----------|---------|-----------|--------------|-------------|
| 1 | Critical | Vuln | {pkg} | {cve} | Reachable | {desc} |

### Summary

- {n} Critical ({r} reachable function, {p} potentially reachable)
- {n} High ({r} reachable function, {p} potentially reachable)
- {n} Secrets / {n} SAST / {n} License risks

### Next Steps

1. `/endor-fix {top-cve}` — Fix top issue
2. `/endor-explain {cve}` — Explain a finding
3. `/endor-findings critical reachable` — Narrow results
```

Offer pagination if more results available.

## Priority Order

1. Critical + Reachable Function
2. Critical + Potentially Reachable
3. High + Reachable Function
4. High + Potentially Reachable
5. Secrets/Credentials
6. Critical + Unreachable
7. SAST Critical/High
8. License issues
9. Medium/Low

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| No findings | No scan run yet — suggest `/endor-scan` |
| Auth error | Suggest `/endor-setup` |
| Filter syntax error | Show correct filter format |
