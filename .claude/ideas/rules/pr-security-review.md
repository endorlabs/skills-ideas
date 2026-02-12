# PR Security Review Rule

Perform a security review when preparing to create a pull request or merge code.

## Trigger

This rule activates when:
- User mentions "PR", "pull request", "merge", "push to main"
- User runs git commands related to PR creation
- User asks to review changes before merging

## Required Actions

Before creating a PR, perform these checks:

### 1. Dependency Changes
If dependency files were modified:
- Use `check_dependency_for_vulnerabilities` MCP tool on new/updated dependencies
- Block if critical vulnerabilities exist

### 2. Secrets Detection
Scan all changed files for:
- Hardcoded credentials, API keys, tokens, private keys
- Block if any secrets detected

### 3. Code Review
For modified source files:
- Check for SQL injection, command injection, XSS patterns
- Check for hardcoded secrets in code
- Block if critical security issues found

### 4. License Compliance
For new dependencies:
- Check license compatibility
- Warn on copyleft licenses (GPL, AGPL)

## Security Gate

**Block PR if:** Critical vulnerabilities, exposed secrets, or critical code vulnerabilities.
**Warn but allow if:** High severity (non-reachable), medium SAST findings, GPL dependencies.
**Pass if:** No critical issues found.

## Do Not Skip

Even if user says "skip security review", always perform at least a quick check on new dependencies and secrets.
