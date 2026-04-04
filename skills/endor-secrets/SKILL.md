---
name: endor-secrets
description: >
  Scan for exposed secrets, credentials, API keys, and sensitive data in your codebase.
  Use when the user says "find secrets", "scan for API keys", "exposed credentials",
  "endor secrets", "check for hardcoded passwords", pre-commit / staged-only secret checks,
  or suspects leaked tokens in code.
  Detects AWS keys, GitHub tokens, Stripe keys, private keys, and more. Do NOT use for
  code vulnerability scanning (/endor-sast) or dependency checks (/endor-sca).
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

**Route by intent** — If the user’s wording indicates **pre-commit** (hook, “before I commit”, “only my staged changes”, etc.), follow **§ Pre-commit / staged-only path** only. Otherwise follow **§ Default path (full repo or directory)**.

---

### Pre-commit / staged-only path

Use this block **end-to-end** for staged / pre-commit secrets checks. **Do not** use the **`scan` MCP tool** here.

**What `endorctl` covers** — **`--pre-commit-checks`** scopes to **staged** changes and **filters out findings that only exist on the base branch**. **Do not** add **`git show`**, **`grep`**, or other manual base-branch logic.

1. **Run `endorctl`** — **`npx -y endorctl`** (see **`CLAUDE.md`** / **`/endor-setup`**). **`--path`** = **absolute** repository root. Follow **Shell and Git** in **`rules/endor-safety.md`** (**`git -C`**, avoid **`cd … &&`** where it causes issues).

```bash
npx -y endorctl scan --path <absolute-repo-root> --secrets --pre-commit-checks -n <namespace>
```

- **Multi-Namespace:** **`-n <namespace>`** matches **`ENDOR_NAMESPACE`** (**`CLAUDE.md`**).
- **Local Development** (**`endorctl init`** / **`~/.endorctl/config.yaml`**): omit **`-n`** if config pins the namespace.
- **Do not** use **`--output-type`** with **`--pre-commit-checks`** (unsupported). Use the CLI default output.

2. **Hydrate (optional)** — If output includes **finding UUIDs**, call **`get_resource`** (`resource_type`: **`Finding`**) per UUID. **Never** print raw secret values. If no UUIDs, parse **file / line / …** from CLI text only — **do not** invent fields.

3. **Present** — Use **§ Pre-commit presentation** in **Step 2: Present results** (two-column table, **Scan mode** line, no **Detail** blocks unless the CLI actually provides them).

---

### Default path (full repo or directory)

Use this block for normal secrets scans (not pre-commit).

1. **`scan` MCP tool**
   - `path`: absolute path to repo root (or directory)
   - `scan_types`: `["secrets"]`
   - `scan_options`: `{ "quick_scan": true }`

2. **Hydrate** — For each finding UUID from **`scan`**, **`get_resource`** (`resource_type`: **`Finding`**) before presenting details.

3. **Present** — Use **§ Default presentation** in **Step 2: Present results** (full table + **Detail** when fields exist).

**CLI fallback (MCP unavailable)** — Only if the user confirms MCP is unavailable:

```bash
npx -y endorctl scan --path $(pwd) --secrets --output-type summary
```

No base-branch filtering unless the user asks.

---

## Step 2: Present results

### Shared rules (both paths)

- **Never** expose literal secrets, risky previews, or dumps of secret-bearing file bodies. Describe remediation in **generic** terms (e.g. env vars, secrets manager). See **`rules/endor-safety.md`** (Safety).

If secrets found, lead with:
> **SECRETS DETECTED** - {count} secret credentials found. **Rotate** if they were **pushed** or live in **remote git history**; if **only local** and never pushed, **fix the code** first — rotation often unnecessary unless the value was committed or otherwise exposed.

**Immediate Actions:**
1. **Rotation** — **If** pushed to a **git remote** (or otherwise exposed: fork, CI, etc.), **rotate** (revoke old, issue new). **If** **only locally** (never committed / never on remote), **rotation usually not required**; remove from code and **do not** push. Still **rotate** if **committed locally** (even unpushed), copied elsewhere, or exposure is **uncertain**.
2. Replace with config / secrets-manager references — **never** paste new secret values here.
3. Check **git history and remotes**; if the secret is in **any commit reachable from a remote**, assume exposure and rotate.

**Remediation (no literals):** generic steps only — no code blocks containing secrets.

### Recommendations

1. **Rotate** what reached a **remote** or **shared** history; for **local-only**, prioritize **removal** and **blocking push** — rotate if committed locally or uncertain.
2. Add to `.gitignore`: `.env`, `.env.local`, `*.pem`, `*.key`, `credentials.json`
3. Use environment variables for secrets; prefer a secrets manager where appropriate.
4. Check history: `git log --all --full-history -- "*.env"`

### Next Steps

- `/endor-scan` — Full scan for other issues  
- `/endor-review` — Pre-PR security check  

For data source policy, read `references/data-sources.md`.

---

### Pre-commit presentation

- **`{count}`** = findings from **`endorctl --pre-commit-checks`** (staged / vs-base already applied by CLI).
- Include **Scan mode** line. Summary table: **only** columns **`#`** and **`Location`** — **do not** fabricate Type / Severity / Description.
- **Omit** per-finding **Detail** blocks unless the CLI provides extra fields (rare).

```markdown
## Secrets Scan Results

**Path:** {scanned path} | **Secrets Found:** {count}

**Scan mode:** pre-commit (`endorctl --pre-commit-checks` — staged changes; pre-existing-on-base handled by CLI)

### Detected Secrets

| # | Location |
|---|----------|
| 1 | `config/aws.js:15` |
```

Then append **Immediate Actions**, **Remediation**, **Recommendations**, and **Next Steps** from **§ Shared rules** above.

---

### Default presentation

- Omit **Scan mode**.
- Use the **full** table when **`get_resource`** (or MCP) supplies type / severity / description / location.
- Add **Detail** blocks per finding when those fields exist.

**Never** output **both** the pre-commit two-column table and the full table in one report.

```markdown
## Secrets Scan Results

**Path:** {scanned path} | **Secrets Found:** {count}

### Detected Secrets

| # | Type | Severity | Description | Location |
|---|------|----------|-------------|----------|
| 1 | AWS Access Key | Critical | Detected long-lived cloud credential | `config/aws.js:15` |

### Detail: {Finding #N}

**Location:** `{file_path}:{line}`  
**Type:** {secret_type}  
**Severity:** {severity}  
**Description:** {finding description / risk summary — no secret literal}
```

Then append **Immediate Actions**, **Remediation**, **Recommendations**, and **Next Steps** from **§ Shared rules** above.

---

## Error handling

### Pre-commit path

| Condition | Action |
|-----------|--------|
| Tempted to use MCP **`scan`** | Use **`endorctl scan … --pre-commit-checks`** only |
| **`endorctl`** / **`npx`** fails (auth, namespace) | **`/endor-setup`**; align **`-n`** with **`CLAUDE.md`** |

### Default path

| Condition | Action |
|-----------|--------|
| Auth error | **`/endor-setup`** |
| MCP not available | **`/endor-setup`**; then CLI fallback if user confirms |

### Both paths

| Condition | Action |
|-----------|--------|
| No secrets found | Confirm the scan completed; suggest periodic re-scanning |
