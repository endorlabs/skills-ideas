---
name: endor-sca
description: >
  Scan all project dependencies for known vulnerabilities using Software Composition
  Analysis. Use when the user says "scan my dependencies", "SCA scan", "vulnerable
  dependencies", "endor sca", "what's wrong with my deps", or wants a focused dependency
  vulnerability report with direct vs transitive breakdown. Do NOT use for checking a
  single package (/endor-check), SAST code scanning (/endor-sast), or quick full scan
  (/endor-scan).
---

# Endor Labs SCA Scanner

Scan project dependencies for known vulnerabilities.

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

Identify ecosystem by checking for manifest/lock files in repository root.

### Step 2: Run Dependency Scan

Use `scan` MCP tool:
- `path`: **absolute path** to repository root
- `scan_types`: `["vulnerabilities", "dependencies"]`
- `scan_options`: `{ "quick_scan": true }`

`dependencies` resolves the tree; `vulnerabilities` matches against Endor Labs DB.

**CLI fallback** (only if MCP genuinely unavailable):
```bash
npx -y endorctl scan --path $(pwd) --dependencies --output-type summary -n <namespace>
```

Show exact error messages — do not guess at causes. Suggest `/endor-troubleshoot` or `/endor-setup` as appropriate.

### Step 3: Retrieve Finding Details

For each critical/high finding UUID, use `get_resource` MCP tool (`uuid`, `resource_type`: `Finding`).

### Step 4: Present Results

Include: scanned path, ecosystem, dependency count, severity summary table (Critical/High/Medium/Low with counts and actions).

For each critical/high finding:
- **Package:** name@version
- **Vulnerability:** CVE ID + brief description
- **Severity:** level (CVSS score if available)
- **Fixed Version:** version or "No fix available"
- **Upgrade Path:** direct dep -> transitive chain if applicable

### Priority Order

1. Critical with fixes -> Critical without fixes
2. High with fixes -> High without fixes
3. Medium/Low

### Direct vs Transitive

Distinguish between direct (in manifest, directly upgradable) and transitive (pulled by parent). For transitive vulns, identify the direct dependency that pulls it in.

### Next Steps

1. `/endor-fix {top-cve}` - fix critical vulnerabilities
2. `/endor-check {package} {version}` - check specific package
3. `/endor-upgrade-impact {package}` - analyze upgrade impact
4. `/endor-scan-full` - full reachability analysis
5. `/endor-license` - check dependency licenses

For data source policy, read references/data-sources.md.

## Error Handling

Show exact error messages — do not guess at causes.

| Error | Action |
|-------|--------|
| No vulns found | Confirm scan complete, suggest `/endor-scan-full` for deeper analysis |
| Auth error | Complete browser login, retry. If persistent, `/endor-setup` |
| No manifest found | List supported ecosystems |
| MCP unavailable | `/endor-setup`. CLI fallback only if user confirms |
| Unknown error | Show exact error, suggest `/endor-troubleshoot` |
