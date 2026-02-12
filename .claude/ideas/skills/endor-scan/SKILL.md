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

### Step 1: Detect Repository Context

Identify the repository being scanned:

1. Determine the **absolute path** to the current working directory (the scan tool requires fully qualified paths)
2. Detect languages by looking for manifest files:
   - `package.json` / `yarn.lock` -> JavaScript/TypeScript
   - `go.mod` / `go.sum` -> Go
   - `requirements.txt` / `pyproject.toml` / `setup.py` -> Python
   - `pom.xml` / `build.gradle` -> Java
   - `Cargo.toml` -> Rust

### Step 2: Run Scan

Determine the scan mode based on user context:

**Full repository scan (default):**

Use the `scan` MCP tool with **all scan types** enabled:

- `path`: The **absolute path** to the repository root (required - must be fully qualified, not relative)
- `scan_types`: `["vulnerabilities", "dependencies", "sast", "secrets"]`
- `scan_options`: `{ "quick_scan": true }`

**Incremental PR scan** (when the user mentions "PR", "pull request", "just my changes", "incremental", or is on a feature branch):

- `path`: The **absolute path** to the repository root
- `scan_types`: `["vulnerabilities", "dependencies", "sast", "secrets"]`
- `scan_options`: `{ "pr_incremental": true }`

The incremental scan only reports **new findings introduced by the current changes** compared to the base branch. This is faster and more focused — ideal for scanning during active development or before a PR.

If the user's intent is ambiguous, default to a full quick scan. If they ask to "scan my changes" or "scan before PR", use incremental mode.

**IMPORTANT:** Always include `"sast"` in `scan_types`. Without it, SAST findings will not be returned.

If the user explicitly requests specific scan types (e.g. "only SCA" or "only SAST"), adjust `scan_types` accordingly, but the default should always include all four types above.

### MCP Tool Failure / CLI Fallback

If the MCP `scan` tool is not available, returns an error, or is not responding:

1. **First, diagnose the actual error.** Read the error message from the MCP tool response carefully. Do NOT guess or assume the cause — report the exact error to the user.

2. **Common causes and fixes:**
   - **Auth error / browser opens**: The MCP server needs authentication. Tell the user to complete the browser login flow, then retry. If no browser opens, check that `ENDOR_MCP_SERVER_AUTH_MODE` is set in `.claude/settings.json`.
   - **MCP server not configured**: Suggest running `/endor-setup` to configure it.
   - **Namespace error**: Check that `ENDOR_NAMESPACE` is set correctly in `.claude/settings.json`.

3. **Only fall back to CLI if the MCP server is genuinely unavailable** (not configured, not installed, or the user explicitly requests CLI mode). Do NOT fall back to CLI just because of an auth error — auth errors should be resolved first.

4. **CLI fallback commands** (only when MCP is genuinely unavailable):

```bash
# Full quick scan (requires prior auth via `endorctl init`)
npx -y endorctl scan --path $(pwd) --quick-scan --dependencies --sast --secrets --output-type summary -n <namespace>

# Incremental PR scan
npx -y endorctl scan --path $(pwd) --pr --dependencies --sast --secrets --output-type summary -n <namespace>
```

**IMPORTANT:** The `--sast` flag must be explicitly passed to the CLI. Without it, only SCA/dependency findings are returned. Similarly, `--secrets` must be explicit. The `--dependencies` flag enables SCA scanning.

**IMPORTANT:** Do NOT invent or fabricate error diagnoses. If you are unsure why a scan failed, show the user the exact error output and suggest `/endor-troubleshoot` or `/endor-setup`.

### Step 3: Retrieve Finding Details

The scan tool returns a list of finding UUIDs sorted by severity. For each critical/high finding, use the `get_resource` MCP tool to retrieve details:

- `uuid`: The finding UUID from the scan results
- `resource_type`: `Finding`

### Step 4: Interpret Reachability Tags

Even in quick scan mode, findings may include reachability tags. **Endor Labs does NOT use simple `FINDING_TAGS_REACHABLE` / `FINDING_TAGS_UNREACHABLE` tags.** Reachability is expressed on **two separate dimensions** in the `finding_tags` array:

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

When presenting findings, use these tags to indicate reachability status. If a finding has `REACHABLE_DEPENDENCY` + `REACHABLE_FUNCTION`, flag it as actively exploitable. If it has `UNREACHABLE_DEPENDENCY` + `UNREACHABLE_FUNCTION`, note it as lower priority. Do NOT report reachability as "undetermined" when these granular tags are present.

### Step 5: Present Results

```markdown
## Security Scan Complete

**Path:** {scanned path}
**Languages:** {detected languages}
**Scan Mode:** {Quick / Incremental PR}

### Vulnerability Summary

| Severity | Count | Action |
|----------|-------|--------|
| Critical | {n} | Fix immediately |
| High | {n} | Fix urgently |
| Medium | {n} | Plan remediation |
| Low | {n} | Track as debt |

### Top Critical/High Findings

| # | Package | CVE | Severity | Reachability | Description |
|---|---------|-----|----------|--------------|-------------|
| 1 | {pkg} | {cve} | Critical | {reachability} | {desc} |
| 2 | {pkg} | {cve} | High | {reachability} | {desc} |

### Next Steps

1. **Fix critical issues:** `/endor-fix {top-cve}`
2. **Deep analysis:** `/endor-scan-full` for full reachability analysis
3. **Check a specific package:** `/endor-check {package}`
4. **View vulnerability details:** `/endor-explain {cve}`
```

### Priority Order

Present findings in this order:
1. Critical vulnerabilities (reachable function first, then unreachable)
2. High vulnerabilities (reachable function first, then unreachable)
3. Secrets/credentials
4. SAST critical/high
5. License issues
6. Medium/Low findings

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for vulnerability or security information.** All scan results and finding data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external vulnerability databases. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

**CRITICAL: Always report exact error messages to the user. Never fabricate, guess, or invent error diagnoses.** If an error occurs, show the user what actually happened and suggest next steps.

- **Auth error / browser opens**: Expected on first use. Tell user to complete browser login, then retry. Do NOT bypass this by switching to CLI — resolve the auth issue first.
- **Missing `ENDOR_MCP_SERVER_AUTH_MODE`**: Tell user to add it to `.claude/settings.json` and restart Claude Code, or run `/endor-setup`.
- **No manifest found**: Tell user no supported project detected, list supported languages.
- **Scan timeout**: Suggest using fewer scan_types or scanning a subdirectory.
- **MCP not available**: Suggest `/endor-setup`. Only fall back to CLI if the user confirms the MCP server cannot be configured.
- **Unknown error**: Show the exact error text to the user. Suggest `/endor-troubleshoot` for diagnosis. Do NOT guess the cause.
