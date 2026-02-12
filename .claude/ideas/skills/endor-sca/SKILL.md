---
name: endor-sca
description: |
  Scan dependencies for known vulnerabilities using Software Composition Analysis (SCA). Identifies vulnerable packages, versions, and available fixes across all supported ecosystems.
  - MANDATORY TRIGGERS: endor sca, sca scan, dependency scan, scan dependencies, vulnerable dependencies, endor-sca, dependency vulnerabilities, vulnerable packages, software composition analysis
---

# Endor Labs SCA Scanner

Scan your project's dependencies for known vulnerabilities using Software Composition Analysis (SCA).

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)

## Supported Ecosystems

| Ecosystem | Manifest Files | Lock Files |
|-----------|---------------|------------|
| JavaScript/TypeScript | `package.json` | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Python | `requirements.txt`, `pyproject.toml`, `setup.py`, `setup.cfg` | `Pipfile.lock`, `poetry.lock` |
| Go | `go.mod` | `go.sum` |
| Java | `pom.xml`, `build.gradle`, `build.gradle.kts` | `gradle.lockfile` |
| Rust | `Cargo.toml` | `Cargo.lock` |
| .NET | `*.csproj`, `packages.config` | `packages.lock.json` |
| Ruby | `Gemfile` | `Gemfile.lock` |
| PHP | `composer.json` | `composer.lock` |

## Workflow

### Step 1: Detect Dependencies

Identify the project's dependency ecosystem by looking for manifest and lock files in the repository root.

### Step 2: Run Dependency Scan

Use the `scan` MCP tool with dependency-specific parameters:

- `path`: The **absolute path** to the repository root (or specific directory)
- `scan_types`: `["vulnerabilities", "dependencies"]`
- `scan_options`: `{ "quick_scan": true }`

The `dependencies` scan type resolves the dependency tree and `vulnerabilities` matches them against the Endor Labs vulnerability database.

### MCP Tool Failure / CLI Fallback

If the MCP `scan` tool returns an error, **report the exact error to the user first** — do NOT guess or fabricate the cause. Only fall back to CLI if the MCP server is genuinely unavailable (not configured or not installed):

```bash
npx -y endorctl scan --path $(pwd) --dependencies --output-type summary -n <namespace>
```

**IMPORTANT:** Do NOT invent or fabricate error diagnoses. If you are unsure why the scan failed, show the user the exact error output and suggest `/endor-troubleshoot` or `/endor-setup`.

### Step 3: Retrieve Finding Details

The scan returns finding UUIDs. For each critical/high finding, use the `get_resource` MCP tool:

- `uuid`: The finding UUID
- `resource_type`: `Finding`

### Step 4: Present Results

```markdown
## Dependency Scan Results

**Path:** {scanned path}
**Ecosystem:** {detected ecosystem(s)}
**Dependencies Scanned:** {total count}

### Vulnerability Summary

| Severity | Count | Action |
|----------|-------|--------|
| Critical | {n} | Fix immediately |
| High | {n} | Fix urgently |
| Medium | {n} | Plan remediation |
| Low | {n} | Track as debt |

### Critical Vulnerabilities

| # | Package | Version | CVE | Severity | Fixed In |
|---|---------|---------|-----|----------|----------|
| 1 | {pkg} | {ver} | {cve} | Critical | {fix_ver} |
| 2 | {pkg} | {ver} | {cve} | Critical | {fix_ver} |

### High Vulnerabilities

| # | Package | Version | CVE | Severity | Fixed In |
|---|---------|---------|-----|----------|----------|
| 1 | {pkg} | {ver} | {cve} | High | {fix_ver} |

### Dependency Details

For each critical/high finding, include:
- **Package:** {name}@{version}
- **Vulnerability:** {CVE ID} — {brief description}
- **Severity:** {severity} ({CVSS score if available})
- **Fixed Version:** {version} (or "No fix available")
- **Upgrade Path:** Direct dependency → transitive chain if applicable

### Next Steps

1. **Fix critical vulnerabilities:** `/endor-fix {top-cve}`
2. **Check a specific package:** `/endor-check {package} {version}`
3. **Analyze upgrade impact:** `/endor-upgrade {package}`
4. **Full reachability scan:** `/endor-scan-full` to see which vulnerabilities are actually reachable
5. **License compliance:** `/endor-license` to check dependency licenses
```

### Priority Order

Present findings in this order:
1. Critical vulnerabilities with known fixes
2. Critical vulnerabilities without fixes
3. High vulnerabilities with known fixes
4. High vulnerabilities without fixes
5. Medium/Low vulnerabilities

### Direct vs Transitive Dependencies

When presenting findings, distinguish between:
- **Direct dependencies** — listed in the project's manifest file, directly upgradable
- **Transitive dependencies** — pulled in by direct dependencies, may require upgrading the parent package

For transitive vulnerabilities, identify the direct dependency that pulls it in and suggest upgrading that package first.

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for vulnerability or dependency information.** All dependency and vulnerability data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external vulnerability databases, package registries, or advisory sites. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

**CRITICAL: Always report exact error messages to the user. Never fabricate, guess, or invent error diagnoses.**

- **No vulnerabilities found**: Good news. Confirm the scan completed and suggest periodic re-scanning or `/endor-scan-full` for deeper reachability analysis.
- **Auth error**: Tell user to complete browser login, then retry. Do NOT bypass by switching to CLI. If persistent, suggest `/endor-setup`.
- **No manifest found**: Tell user no supported dependency files were detected. List supported ecosystems.
- **MCP not available**: Suggest `/endor-setup`. Only fall back to CLI if the user confirms MCP cannot be configured.
- **Unknown error**: Show the exact error text to the user. Suggest `/endor-troubleshoot`. Do NOT guess the cause.
