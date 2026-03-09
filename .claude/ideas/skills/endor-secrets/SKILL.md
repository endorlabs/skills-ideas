---
name: endor-secrets
description: |
  Scan for exposed secrets, credentials, API keys, and sensitive data in your codebase. Detects hardcoded passwords, tokens, private keys, and more.
  - MANDATORY TRIGGERS: endor secrets, scan secrets, find secrets, exposed credentials, hardcoded secrets, api keys exposed, endor-secrets, find credentials, secret scan
---

# Endor Labs Secrets Scanner

## Secret Types Detected

| Type | Pattern | Risk |
|------|---------|------|
| AWS Access Key | `AKIA[0-9A-Z]{16}` | Cloud compromise |
| AWS Secret Key | 40-char base64 | Cloud compromise |
| GitHub Token | `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` | Repo access |
| GitLab Token | `glpat-` | Repo access |
| Slack Token | `xox[baprs]-` | Workspace access |
| Stripe Key | `sk_live_`, `pk_live_`, `sk_test_` | Payment data |
| Google API Key | `AIza[0-9A-Za-z-_]{35}` | Service abuse |
| Private Key | `-----BEGIN.*PRIVATE KEY-----` | Auth bypass |
| Database URL | Connection strings with creds | Data breach |
| JWT Secret | `jwt_secret`, `JWT_KEY` patterns | Token forging |
| NPM Token | `npm_` | Package publish |
| PyPI Token | `pypi-` | Package publish |

## Workflow

### Step 1: Run Secrets Scan

Use `scan` MCP tool:
- `path`: absolute path to repo root (or specific directory)
- `scan_types`: `["secrets"]`
- `scan_options`: `{ "quick_scan": true }`

For each finding UUID returned, use `get_resource` MCP tool with `resource_type`: `Finding`.

CLI fallback:
```bash
npx -y endorctl scan --path $(pwd) --secrets --output-type summary
```

### Step 2: Present Results

If secrets found, lead with:
> **SECRETS DETECTED** - {count} exposed credentials found. Rotate immediately -- they may already be compromised if committed to version control.

```markdown
## Secrets Scan Results

**Path:** {scanned path} | **Secrets Found:** {count}

### Exposed Secrets

| # | Type | File | Line | Risk |
|---|------|------|------|------|
| 1 | AWS Access Key | config/aws.js | 15 | Critical |

### Detail: {Secret #N}

**File:** {file_path}:{line}
**Type:** {secret_type}
**Risk:** {risk_description}

**Immediate Actions:**
1. Rotate this secret immediately (generate new, revoke old)
2. Replace with environment variable reference
3. Check git history for prior commits

**Secure Alternative:**
{Show before/after code replacing hardcoded secret with env var}

### Recommendations

1. Rotate all exposed secrets immediately
2. Add to .gitignore: `.env`, `.env.local`, `*.pem`, `*.key`, `credentials.json`
3. Use environment variables for all secrets
4. Use a secrets manager (AWS Secrets Manager, HashiCorp Vault, etc.)
5. Check git history: `git log --all --full-history -- "*.env"`

### Next Steps

- `/endor-scan` - Full scan for other issues
- `/endor-review` - Pre-PR security check
```

For data source policy, read references/data-sources.md.

## Error Handling

| Condition | Action |
|-----------|--------|
| No secrets found | Confirm scan completed; suggest periodic re-scanning |
| Auth error | Suggest `/endor-setup` |
| MCP not available | Suggest `/endor-setup` to configure |
