---
name: endor-scan
description: |
  Perform a fast security scan of the current repository using Endor Labs. Identifies vulnerabilities, license issues, and secrets without full reachability analysis.
  - MANDATORY TRIGGERS: endor scan, quick scan, security scan, scan repo, scan repository, scan my code, endor-scan
---

# Endor Labs Quick Scan

Fast security scan of the current repository.

## Workflow

### Step 1: Detect Repository Context

1. Determine **absolute path** to cwd (scan tool requires fully qualified paths)
2. Detect languages via manifest files: `package.json`/`yarn.lock` (JS/TS), `go.mod`/`go.sum` (Go), `requirements.txt`/`pyproject.toml`/`setup.py` (Python), `pom.xml`/`build.gradle` (Java), `Cargo.toml` (Rust)

### Step 2: Run Scan

**Full repository scan (default)** - use `scan` MCP tool:
- `path`: **absolute path** to repository root
- `scan_types`: `["vulnerabilities", "dependencies", "sast", "secrets"]`
- `scan_options`: `{ "quick_scan": true }`

**Incremental PR scan** (user mentions "PR", "pull request", "just my changes", "incremental", or is on feature branch):
- Same `path` and `scan_types`
- `scan_options`: `{ "pr_incremental": true }`

Incremental scan reports only **new findings** vs base branch. Default to full quick scan if intent is ambiguous.

Always include `"sast"` in `scan_types` unless user explicitly requests specific types.

**CLI fallback** (only if MCP genuinely unavailable):
```bash
# Full quick scan
npx -y endorctl scan --path $(pwd) --quick-scan --dependencies --sast --secrets --output-type summary -n <namespace>

# Incremental PR scan
npx -y endorctl scan --path $(pwd) --pr --dependencies --sast --secrets --output-type summary -n <namespace>
```

CLI requires explicit `--sast`, `--secrets`, `--dependencies` flags.

Never fabricate error diagnoses. Show exact errors and suggest `/endor-troubleshoot` or `/endor-setup`.

### Step 3: Retrieve Finding Details

For each critical/high finding UUID, use `get_resource` MCP tool (`uuid`, `resource_type`: `Finding`).

### Step 4: Interpret Reachability Tags

For reachability tag interpretation, read references/reachability-tags.md.

### Step 5: Present Results

Include: scanned path, detected languages, scan mode (Quick/Incremental PR), severity summary table.

Top critical/high findings table: Package, CVE, Severity, Reachability, Description.

### Priority Order

1. Critical vulns (reachable first)
2. High vulns (reachable first)
3. Secrets/credentials
4. SAST critical/high
5. License issues
6. Medium/Low

### Next Steps

1. `/endor-fix {top-cve}` - fix critical issues
2. `/endor-scan-full` - full reachability analysis
3. `/endor-check {package}` - check specific package
4. `/endor-explain {cve}` - vulnerability details

For data source policy, read references/data-sources.md.

## Error Handling

Never fabricate error diagnoses. Show exact error messages.

| Error | Action |
|-------|--------|
| Auth error / browser opens | Complete browser login, retry. Do not bypass to CLI |
| Missing `ENDOR_MCP_SERVER_AUTH_MODE` | Add to `.claude/settings.json`, restart, or `/endor-setup` |
| No manifest found | List supported languages |
| Scan timeout | Use fewer scan_types or scan subdirectory |
| MCP unavailable | `/endor-setup`. CLI fallback only if user confirms |
| Unknown error | Show exact error, suggest `/endor-troubleshoot` |
