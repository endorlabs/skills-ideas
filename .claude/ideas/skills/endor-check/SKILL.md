---
name: endor-check
description: |
  Check if a specific dependency has known vulnerabilities. Provide a package name and optionally a version to get vulnerability information.
  - MANDATORY TRIGGERS: endor check, check dependency, check package, check vulnerability, is this package safe, endor-check
---

# Endor Labs Dependency Check

Check a specific dependency for known vulnerabilities.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)

## Input Parsing

Parse the user's input to extract:

1. **Package name** (required) - e.g., `lodash`, `express`, `django`
2. **Version** (optional) - e.g., `4.17.15`, `2.0.0`
3. **Language** (optional) - auto-detect from context if not specified

### Language Detection

If the user doesn't specify a language, detect it from:
1. The package name pattern (e.g., `@angular/core` -> JavaScript)
2. Manifest files in the current directory
3. Ask the user if ambiguous

### Ecosystem Mapping

The MCP tool uses specific ecosystem names:

| Package Manager | `ecosystem` Parameter |
|-----------------|----------------------|
| npm/yarn | `npm` |
| pip/poetry | `python` |
| Go modules | `go` |
| Maven | `maven` |
| Gradle | `java` |

Note: For Maven packages, use `groupid:artifactid` format for the dependency name (e.g., `org.apache.logging.log4j:log4j-core`).

## Workflow

### Step 1: Check for Vulnerabilities

Use the `check_dependency_for_vulnerabilities` MCP tool:

- `ecosystem`: Package ecosystem (see mapping above)
- `dependency_name`: Package name (for Maven: `groupid:artifactid`)
- `version`: Specified version

### Step 2: Present Results

#### If Vulnerabilities Found

```markdown
## Vulnerability Check: {package}@{version}

**Status:** VULNERABLE
**Language:** {language}

### Vulnerabilities Found

| CVE | Severity | Description | Fixed In |
|-----|----------|-------------|----------|
| {cve} | Critical | {desc} | {fixed_version} |
| {cve} | High | {desc} | {fixed_version} |

### Recommended Action

Upgrade to **{safe_version}** to resolve all known vulnerabilities:

```bash
# npm
npm install {package}@{safe_version}

# yarn
yarn add {package}@{safe_version}

# pip
pip install {package}=={safe_version}

# go
go get {package}@v{safe_version}
```

### Next Steps

1. **Get fix details:** `/endor-fix {top-cve}`
2. **Check upgrade impact:** `/endor-upgrade {package} {safe_version}`
3. **View package health:** `/endor-score {package}`
```

#### If No Vulnerabilities Found

```markdown
## Vulnerability Check: {package}@{version}

**Status:** NO KNOWN VULNERABILITIES
**Language:** {language}

This version has no known vulnerabilities in the Endor Labs database.

### Additional Checks

- **Package health:** `/endor-score {package}`
- **License check:** `/endor-license`
```

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for vulnerability or package information.** All data MUST come from the `check_dependency_for_vulnerabilities` MCP tool or the `endorctl` CLI. Do NOT search the web, visit package registries (npmjs.com, pypi.org, etc.), or external vulnerability databases. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

- **Package not found**: Suggest checking the package name and ecosystem. Do NOT look up the package on external websites.
- **Version not found**: Show available versions from Endor Labs or check latest
- **Auth error**: Suggest `/endor-setup`
- **MCP not available**: Suggest running `/endor-setup` to configure the MCP server
