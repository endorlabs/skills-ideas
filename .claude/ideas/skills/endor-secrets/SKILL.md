---
name: endor-secrets
description: |
  Scan for exposed secrets, credentials, API keys, and sensitive data in your codebase. Detects hardcoded passwords, tokens, private keys, and more.
  - MANDATORY TRIGGERS: endor secrets, scan secrets, find secrets, exposed credentials, hardcoded secrets, api keys exposed, endor-secrets, find credentials, secret scan
---

# Endor Labs Secrets Scanner

Scan your codebase for exposed secrets, credentials, and sensitive data.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)

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

Use the `scan` MCP tool with secrets-specific parameters:

- `path`: The **absolute path** to the repository root (or specific directory)
- `scan_types`: `["secrets"]`
- `scan_options`: `{ "quick_scan": true }`

The scan returns finding UUIDs. For each finding, use the `get_resource` MCP tool:
- `uuid`: The finding UUID
- `resource_type`: `Finding`

If the MCP tool is not available, fall back to CLI:

```bash
npx -y endorctl scan --path $(pwd) --secrets --output-type summary
```

### Step 2: Present Results

```markdown
## Secrets Scan Results

**Path:** {scanned path}
**Secrets Found:** {count}

### Exposed Secrets

| # | Type | File | Line | Risk |
|---|------|------|------|------|
| 1 | AWS Access Key | config/aws.js | 15 | Critical - Cloud compromise |
| 2 | Database Password | .env | 3 | Critical - Data breach |
| 3 | GitHub Token | scripts/deploy.sh | 42 | High - Repo access |

### Detail: {Secret #1}

**File:** {file_path}:{line}
**Type:** {secret_type}
**Risk:** {risk_description}

**Immediate Actions:**
1. **Rotate this secret immediately** - Generate a new key/token and revoke the old one
2. **Remove from code** - Replace with environment variable reference
3. **Check git history** - The secret may be in previous commits

**Secure Alternative:**
```{language}
// Before (INSECURE)
const awsKey = "AKIA...";

// After (SECURE)
const awsKey = process.env.AWS_ACCESS_KEY_ID;
```

### Recommendations

1. **Rotate all exposed secrets immediately**
2. **Add sensitive files to .gitignore:**
   ```
   .env
   .env.local
   *.pem
   *.key
   credentials.json
   ```
3. **Use environment variables** for all secrets
4. **Use a secrets manager** (AWS Secrets Manager, HashiCorp Vault, etc.)
5. **Check git history** for previously committed secrets:
   ```bash
   git log --all --full-history -- "*.env"
   ```

### Next Steps

1. **Rotate secrets** listed above
2. **Run full scan:** `/endor-scan` to check for other issues
3. **Pre-PR check:** `/endor-review` before pushing changes
```

## Immediate Alert Format

If secrets are found, present them with urgency:

> **SECRETS DETECTED** - {count} exposed credentials found. These should be rotated immediately as they may already be compromised if committed to version control.

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for secrets detection information.** All data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external sources. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

- **No secrets found**: Good news. Confirm the scan completed and suggest periodic re-scanning.
- **Auth error**: Suggest `/endor-setup`
- **MCP not available**: Suggest running `/endor-setup` to configure
