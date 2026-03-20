---
name: endor-troubleshoot
description: >
  Troubleshoot Endor Labs scan errors and failures. Use when the user says "scan failed",
  "why did the scan fail", "endor troubleshoot", "fix scan error", "diagnose error", or
  pastes an error message from a failed scan. Matches errors against known patterns across
  NPM, Maven, PyPI, Go, Cargo, NuGet, RubyGems, and Packagist. Do NOT use for setup
  issues (/endor-setup) or general scanning (/endor-scan).
---

# Endor Labs Scan Error Troubleshooter

## Input Parsing

Accept input as: pasted error text, scan-and-diagnose request, or natural language description.

If no error text provided, ask:
> 1. **Run a scan** on the current repository and diagnose errors?
> 2. **Analyze error text** you paste in?

For scan mode, use `scan` MCP tool: `path`=repo path, `scan_types`=`["vulnerabilities", "dependencies"]`, `scan_options`=`{ "quick_scan": true }`. Parse results for errors and match against knowledge base.

## Workflow

### Step 1: Detect Ecosystem

| Indicator | Ecosystem |
|-----------|-----------|
| `npm ERR!`, `yarn`, `pnpm`, `package.json`, `node_modules` | NPM |
| `pom.xml`, `mvn`, `gradle`, `Maven`, `Gradle`, `artifact`, `.jar`, `groupId` | Maven/Gradle |
| `pip`, `poetry`, `pypi`, `setup.py`, `pyproject.toml`, `requirements.txt` | PyPI |
| `go:`, `go.mod`, `go.sum`, `GOPATH`, `GOPROXY` | Go |
| `cargo`, `Cargo.toml`, `Cargo.lock`, `crate`, `rustc` | Cargo |
| `dotnet`, `nuget`, `.csproj`, `.sln`, `NuGet`, `TargetFramework` | NuGet |
| `gem`, `bundle`, `Gemfile`, `bundler`, `.gemspec` | RubyGems |
| `composer`, `packagist`, `composer.json`, `composer.lock` | Packagist |

No match? Check cross-ecosystem patterns (GitHub Packages, registry/artifactory, sandbox errors).

### Step 2: Classify Error Category

**Private Registry** -- package not found, auth failures (401/403), SSH/Git credential errors, connection refused/timeout, missing registry config.

**Toolchain** -- language/SDK version mismatches, missing SDKs/build tools, lock file format issues, compiler/build config errors.

**Other** -- invalid manifests, compilation errors, missing build deps, plugin failures.

### Step 3: Match Against Known Patterns

Read `references/error-knowledge-base.md` and match the error text against patterns for the detected ecosystem and category.

### Step 4: Present Diagnosis

```markdown
## Scan Error Diagnosis

### Error Identified

| Field | Value |
|-------|-------|
| Ecosystem | {ecosystem} |
| Category | {Private Registry / Toolchain / Other} |
| Error | {description} |
| Fixable | {Yes / No / Partially} |

### What This Means
{Plain-language explanation}

### Resolution
{Step-by-step remediation from matching rule}

{If Scan Profile fix:} Update [Scan Profile](https://docs.endor.ai/docs/scan-profiles/) with correct toolchain version.
{If Private Registry fix:} Configure [Private Package Registry](https://docs.endor.ai/docs/integrations/private-package-registries), or set credentials in CI.
{If not fixable in cloud:} Move scanning to CI/CD pipeline.

### Next Steps
- `/endor-scan` - Re-run after fix
- `/endor-setup` - Reconfigure if needed
```

### Step 5: Handle Multiple Errors

1. Identify all distinct errors
2. Diagnose each separately
3. Present in priority order: Private Registry > Toolchain > Other
4. Note if fixing one may resolve others

## Common Resolution Patterns

**Private Registry**: Check if package is private -> configure [Private Package Registry](https://docs.endor.ai/docs/integrations/private-package-registries) or set CI credentials -> verify registry is internet-accessible from cloud.

**Toolchain**: Identify required version from error -> update [Scan Profile](https://docs.endor.ai/docs/scan-profiles/) -> re-scan.

**Cloud Scanning Limitations** (move to CI): SSH Git deps, system package installation (python3-dev, PostgreSQL libs), Windows builds, custom env vars, Docker builds.

For data source policy, read references/data-sources.md.

## Error Handling

| Condition | Action |
|-----------|--------|
| No pattern match | Suggest [docs.endorlabs.com](https://docs.endorlabs.com), fresh `/endor-scan`, or Endor Labs support |
| Multiple ecosystems | Ask user to clarify which to troubleshoot first |
| Auth error from MCP | Suggest `/endor-setup` |
| Scan tool unavailable | Analyze pasted error text only |
