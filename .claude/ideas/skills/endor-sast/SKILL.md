---
name: endor-sast
description: |
  Perform static application security testing (SAST) to find code vulnerabilities like SQL injection, XSS, command injection, and more.
  - MANDATORY TRIGGERS: endor sast, static analysis, code vulnerabilities, sql injection, xss, command injection, endor-sast, sast scan, code security
---

# Endor Labs SAST Scanner

Perform static application security testing to find code-level vulnerabilities.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)

## Vulnerability Categories

| Category | CWE | Risk |
|----------|-----|------|
| SQL Injection | CWE-89 | Critical - Data breach |
| Command Injection | CWE-78 | Critical - System compromise |
| XSS (Cross-Site Scripting) | CWE-79 | High - Session hijacking |
| Path Traversal | CWE-22 | High - File access |
| Insecure Deserialization | CWE-502 | High - Remote code execution |
| Hardcoded Credentials | CWE-798 | High - Auth bypass |
| Weak Cryptography | CWE-327 | Medium - Data exposure |
| Information Disclosure | CWE-200 | Medium - Data leakage |
| CORS Misconfiguration | CWE-942 | Medium - Cross-origin attacks |
| Debug Mode in Production | CWE-489 | Medium - Info exposure |

## AI False Positive Reduction

Endor Labs offers AI-powered false positive analysis that uses an AI agent to review SAST findings and filter out false positives. This significantly reduces noise and lets you focus on real vulnerabilities.

**This feature requires an Endor Labs Code Pro license.** When presenting the option, inform the user that AI false positive reduction is a Code Pro capability.

**Before running the scan, ask the user if they want to enable AI false positive reduction.** Present it as an option:

- **Without AI analysis** (default): Faster scan, may include false positives
- **With AI analysis** (requires Code Pro license): Slower scan, but filters out false positives using AI review

If the user opts in (or says things like "reduce false positives", "use AI", "filter noise"), enable the `--ai-sast-analysis=agent-fallback` flag. If they encounter a licensing error, explain that this feature requires the Endor Labs Code Pro license and suggest they contact their Endor Labs account team or visit [endorlabs.com](https://www.endorlabs.com) for more information.

## Workflow

### Step 1: Run SAST Scan

Use the `scan` MCP tool with SAST-specific parameters:

- `path`: The **absolute path** to the repository root (or specific directory)
- `scan_types`: `["sast"]`
- `scan_options`: `{ "quick_scan": true }`

If the MCP tool is not available, fall back to CLI:

**Standard SAST scan:**
```bash
npx -y endorctl scan --path $(pwd) --sast --output-type summary 2>/dev/null
```

**SAST scan with AI false positive reduction:**
```bash
npx -y endorctl scan --path $(pwd) --sast --ai-sast-analysis=agent-fallback --output-type summary 2>/dev/null
```

The `--ai-sast-analysis=agent-fallback` flag enables an AI agent that reviews each SAST finding to determine if it is a true positive or false positive. Findings identified as false positives are automatically filtered out of the results.

### Step 2: Retrieve Finding Details

The scan returns finding UUIDs. For each finding, use the `get_resource` MCP tool:

- `uuid`: The finding UUID
- `resource_type`: `Finding`

### Step 3: Analyze Code Context

Read the source files referenced in the findings to show the vulnerable code with surrounding context. Use the file path and line numbers from the finding data.

### Step 4: Present Results

```markdown
## SAST Analysis Results

**Path:** {scanned path}
**Issues Found:** {count}
**AI False Positive Reduction:** {Enabled/Disabled}

### Critical Issues

#### {Issue #1}: {Title} ({CWE-ID})

**File:** {file_path}:{line}
**Severity:** Critical
**CWE:** {CWE-ID} - {CWE Name}

**Vulnerable Code:**
```{language}
{vulnerable code snippet with line numbers}
```

**Why This Is Dangerous:**
{Brief explanation of the vulnerability and its impact}

**Recommended Fix:**
```{language}
{fixed code snippet}
```

### High Issues

{Same format as critical}

### Medium Issues

{Same format, briefer}

### Summary

| Severity | Count | Categories |
|----------|-------|------------|
| Critical | {n} | {SQL Injection, Command Injection, ...} |
| High | {n} | {XSS, Path Traversal, ...} |
| Medium | {n} | {Weak Crypto, Info Disclosure, ...} |
| Low | {n} | {Misc} |

### Next Steps

1. **Fix critical issues first** - These are exploitable vulnerabilities
2. **Run again after fixes:** `/endor-sast` to verify
3. **Full security scan:** `/endor-scan-full` for complete analysis
4. **Pre-PR check:** `/endor-review` before merging
```

## Language-Specific Guidance

When presenting fixes, include language-specific secure patterns:

### JavaScript/TypeScript
- Use `===` instead of `==`
- Avoid `eval()`, `Function()`, `setTimeout(string)`
- Use `textContent` instead of `innerHTML`
- Use `crypto.randomUUID()` not `Math.random()` for IDs

### Python
- Use parameterized queries, not f-strings for SQL
- Use `subprocess.run([], shell=False)` not `os.system()`
- Use `secrets` module for cryptographic operations
- Avoid `pickle.loads()` with untrusted data

### Go
- Use `html/template` not `text/template` for HTML
- Use `crypto/rand` not `math/rand` for security
- Use `filepath.Clean()` for path operations

### Java
- Use `PreparedStatement` for SQL
- Use `java.security.SecureRandom`
- Avoid `Runtime.exec()` with user input

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for vulnerability or code security information.** All SAST findings MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external sources. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

- **No issues found**: Confirm the scan completed successfully. Suggest running `/endor-scan-full` for deeper analysis.
- **Auth error**: Suggest `/endor-setup`
- **Unsupported language**: List supported languages and suggest alternatives
