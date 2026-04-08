---
name: endor-supply-chain
description: >
  Assess supply chain risk for your repository by scanning dependencies, secrets, and
  GitHub Actions workflows using Endor Labs. Use when the user says "supply chain risk",
  "supply chain assessment", "assess my supply chain", "endor supply chain", "third-party
  risk", "software supply chain", or wants a combined view of dependency vulnerabilities,
  leaked secrets, and CI/CD pipeline risks. Do NOT use for code-level SAST scanning
  (/endor-sast), single package checks (/endor-check), or full reachability analysis
  (/endor-scan-full).
---

# Endor Labs Supply Chain Risk Assessment

Assess supply chain risk by scanning dependencies (SCA), secrets, and GitHub Actions workflows in a single combined report.

## Scope

This assessment covers three supply chain attack surfaces:

| Surface | What It Detects | Scan Type |
|---------|----------------|-----------|
| **Dependencies (SCA)** | Known vulnerabilities, malware, unmaintained packages | `vulnerabilities`, `dependencies` |
| **Secrets** | Hardcoded credentials, API keys, tokens in source | `secrets` |
| **GitHub Actions** | Unsafe workflow patterns, pinning issues, injection risks | `ghactions` |

## Workflow

### Step 1: Detect Project Context

1. Determine **absolute path** to repository root
2. Detect ecosystem by checking for manifest/lock files: `package.json`/`yarn.lock` (JS/TS), `go.mod`/`go.sum` (Go), `requirements.txt`/`pyproject.toml` (Python), `pom.xml`/`build.gradle` (Java), `Cargo.toml` (Rust)
3. Check for `.github/workflows/` directory — if absent, note that GitHub Actions scan will be skipped

### Step 2: Run Supply Chain Scan

Use `scan` MCP tool:
- `path`: **absolute path** to repository root
- `scan_types`: `["vulnerabilities", "dependencies", "secrets", "ghactions"]`
- `scan_options`: `{ "quick_scan": true }`

**CLI fallback** (only if MCP genuinely unavailable):
```bash
npx -y endorctl scan --path $(pwd) --dependencies --secrets --ghactions --output-type summary -n <namespace>
```

Show exact error messages — do not guess at causes.

If a scan partially succeeds (e.g., dependency scan works but GitHub Actions scan finds no workflows), present the available results with a note about which scan types returned no data. Do not discard partial results.

### Step 3: Retrieve Finding Details

For each critical/high finding UUID, use `get_resource` MCP tool (`uuid`, `resource_type`: `Finding`).

For reachability tag interpretation, read references/reachability-tags.md.

### Step 4: Present Supply Chain Risk Report

Structure the report as three sections, one per attack surface:

```markdown
## Supply Chain Risk Assessment

**Repository:** {repo path}
**Ecosystem:** {detected ecosystem}
**Scan Date:** {date}

---

### 1. Dependency Vulnerabilities (SCA)

**Dependencies Scanned:** {count} | **Findings:** {count}

| Severity | Count | Reachable | Action |
|----------|-------|-----------|--------|
| Critical | {n}   | {n}       | Fix immediately |
| High     | {n}   | {n}       | Fix soon |
| Medium   | {n}   | -         | Review |
| Low      | {n}   | -         | Monitor |

**Top Findings:**

| Package | Version | CVE | Severity | Reachable | Fixed In |
|---------|---------|-----|----------|-----------|----------|
| {name}  | {ver}   | {cve} | {sev}  | {yes/no}  | {ver}    |

Distinguish direct vs transitive dependencies. For transitive vulns, identify the direct dependency that pulls them in.

---

### 2. Exposed Secrets

**Secrets Found:** {count}

| # | Type | File | Line | Risk |
|---|------|------|------|------|
| 1 | {type} | {file} | {line} | {risk} |

If secrets found, include urgent rotation guidance:
> **ACTION REQUIRED** — Rotate all exposed secrets immediately. Secrets committed to version control should be considered compromised.

---

### 3. GitHub Actions Risks

**Workflows Scanned:** {count} | **Findings:** {count}

| # | Workflow | Issue | Severity | Recommendation |
|---|----------|-------|----------|----------------|
| 1 | {file}   | {issue} | {sev}  | {fix}          |

If no `.github/workflows/` directory exists, note:
> No GitHub Actions workflows found — this section is not applicable.

---

### Supply Chain Risk Summary

| Attack Surface | Risk Level | Key Issue |
|----------------|------------|-----------|
| Dependencies   | {Critical/High/Medium/Low/Clean} | {top issue or "No vulnerabilities found"} |
| Secrets        | {Critical/Clean} | {top issue or "No secrets detected"} |
| GitHub Actions | {High/Medium/Low/Clean} | {top issue or "No issues found"} |

**Overall Supply Chain Risk:** {Critical/High/Medium/Low}
```

### Priority Order

1. Critical reachable dependency vulnerabilities
2. Exposed secrets (always critical)
3. Critical unreachable dependency vulnerabilities
4. High reachable dependency vulnerabilities
5. GitHub Actions critical/high issues
6. High unreachable dependency vulnerabilities
7. Medium/Low findings across all categories

### Next Steps

1. `/endor-fix {top-cve}` — remediate critical dependency vulnerabilities
2. `/endor-secrets` — deep-dive on exposed secrets with rotation guidance
3. `/endor-check {package}` — investigate a specific dependency
4. `/endor-explain {cve}` — get detailed CVE information
5. `/endor-scan-full` — full reachability analysis for dependency findings
6. `/endor-cicd` — add Endor Labs to CI/CD pipeline for continuous monitoring
7. `/endor-policy` — create policies to enforce supply chain standards

For data source policy, read references/data-sources.md.

## Error Handling

Show exact error messages — do not guess at causes. Suggest `/endor-troubleshoot` or `/endor-setup` as appropriate.

| Error | Action |
|-------|--------|
| Auth error / browser opens | Complete browser login, retry. Do not bypass to CLI |
| Missing auth config | Run `/endor-setup` to choose an auth workflow |
| No manifest found | List supported ecosystems, still run secrets + ghactions scans |
| No GitHub workflows | Skip ghactions section, present SCA + secrets results |
| Scan timeout | Run each scan type separately or scan subdirectory |
| MCP unavailable | `/endor-setup`. CLI fallback only if user confirms |
| Unknown error | Show exact error, suggest `/endor-troubleshoot` |
