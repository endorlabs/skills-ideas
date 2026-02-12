# Secrets Detection Rule

Scan for exposed secrets, credentials, and sensitive data when creating or modifying files.

## Trigger

This rule activates when you:
- Create or modify configuration files
- Write code that handles authentication
- Create environment files or templates
- Modify CI/CD configurations

## Secret Patterns to Detect

- AWS Access Keys: `AKIA[0-9A-Z]{16}`
- AWS Secret Keys: 40-character base64 strings
- GitHub Tokens: `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` prefixes
- Slack Tokens: `xox[baprs]-` prefix
- Stripe Keys: `sk_live_`, `pk_live_`, `sk_test_`
- Private Keys: `-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----`
- Database URLs with embedded credentials
- API keys and tokens in code

## Required Actions

**BEFORE writing any code or config that might contain secrets:**

1. Scan the content for secret patterns
2. If secrets detected: STOP, do NOT write the file
3. Replace hardcoded secrets with environment variable references
4. Suggest using a secrets manager

**Use Secure Alternatives:**
```javascript
// BAD
const apiKey = "sk_live_abc123xyz";
// GOOD
const apiKey = process.env.API_KEY;
```

## Environment File Handling

- Create `.env.example` with placeholder values (safe to commit)
- Add `.env` to `.gitignore`
- Never commit actual secrets

## Do Not Commit Secrets

Even if the user says "it's just for testing" or "I'll change it later", always use environment variables. Test secrets often end up in production.
