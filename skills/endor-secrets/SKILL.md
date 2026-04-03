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

### Step 1: Run Secrets Scan

**Default (repo or directory scope)** — Use `scan` MCP tool:
- `path`: absolute path to repo root (or specific directory)
- `scan_types`: `["secrets"]`
- `scan_options`: `{ "quick_scan": true }`

**Pre-commit / staged files only** — When the user’s wording indicates **pre-commit** (hook, “before I commit”, “only my staged changes”, etc.), use the same `scan` call but narrow the scan with `include_path`, then **only present findings that are not already present on the base branch of the branch you are on** — i.e. the branch you compare against to decide what already existed before your changes (see filtering below).

1. **Collect staged paths** — Run **`git -C <absolute-repo-root> diff --cached --name-only`**, following **Shell and Git (Claude Code)** in `rules/endor-safety.md` (avoid `cd … && git …`). Skip empty lines. If there is no output, nothing is staged — tell the user and do not call `scan` for a staged-only run.
2. **Call `scan`** — Add those paths to `scan_options` alongside `quick_scan`, for example:

```json
{
  "path": "/absolute/path/to/repo/root",
  "scan_types": ["secrets"],
  "scan_options": {
    "quick_scan": true,
    "include_path": ["<file1>", "<file2>"]
  }
}
```

Set `path` to the repository root; use staged paths for `include_path` as Git emits them (typically repo-relative).

3. **Resolve the base branch ref (git only)** — Choose `<base-ref>`: the branch your **current** branch is **based on** for this comparison (usually the default branch, e.g. `main`). Prefer **`git -C <absolute-repo-root> symbolic-ref refs/remotes/origin/HEAD`**: it resolves to something like `refs/remotes/origin/main` — use **`origin/main`** (or whatever short name that implies) as `<base-ref>`. If that fails (no `origin`, or no remote HEAD), try **`git -C <absolute-repo-root> rev-parse --verify`** against **`origin/main`**, then **`origin/master`**, then **`origin/develop`**. Ask the user which ref to use if none resolve. All **`git`** invocations use **`git -C <absolute-repo-root>`** (see `rules/endor-safety.md`).

   **Remote (`origin/main`) vs local (`main`)** — **`origin/main`** is a *remote-tracking* ref: it reflects the last **`git fetch`** from `origin` and works even when you **never** have a local `main` checked out (typical feature-only workflows). Local **`main`** may not exist, or may be **stale** if you have not merged/rebased/pull recently. Prefer **`origin/...`** for a stable default; use **`main`** only when it exists and you explicitly want to compare against that local branch (e.g. it is current).

4. **Hydrate each finding** — For **each** finding UUID returned by `scan`, call **`get_resource`** with **`resource_type`: `Finding`** to obtain the **file path** and the **detected secret value** (or equivalent matched material needed to test equality).

5. **Filter against base with `git show`** — For each hydrated finding, let `<path>` be the repo-relative file path and `<secret>` be the same secret string the scanner reported:
   - Run **`git -C <absolute-repo-root> show <base-ref>:<path>`** (quote `<path>` if it contains special characters).
   - If that command **fails** (e.g. file did **not** exist on the base branch), **keep** the finding — it cannot already exist on the base.
   - If it **succeeds**, search the printed blob for **`<secret>`** (or the same normalized match the scanner used). If **the same secret appears** in that base revision, **omit** the finding from the user-facing result (it was already on the base branch). If the secret **does not** appear in the base blob, **keep** the finding.

6. **Present** — In Step 2, report **only** findings **kept** after step 5. State clearly that the list is **new vs base `<base-ref>`** (the base branch for your current branch), not the full raw scan list.

**Default (non–pre-commit) scans** — For each finding UUID returned, use **`get_resource`** with **`resource_type`: `Finding`** before presenting details. No base-branch filtering unless the user asks for it.

CLI fallback:
```bash
npx -y endorctl scan --path $(pwd) --secrets --output-type summary
```

### Step 2: Present Results

If secrets found, lead with:
> **SECRETS DETECTED** - {count} exposed credentials found. Rotate immediately -- they may already be compromised if committed to version control.

For **pre-commit / staged-only** runs, `{count}` must be the number of findings **after** base-branch filtering (`git show` check). Include the **Compared to base** line below; omit it for full-repo scans.

```markdown
## Secrets Scan Results

**Path:** {scanned path} | **Secrets Found:** {count}

**Compared to base:** `<base-ref>` — only secrets not already present in that base branch’s version of each file *(pre-commit / staged-only)*

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
| Pre-commit: every finding matched base branch (`git show`) | Report **zero new secrets vs base**; raw scan may still have matched pre-existing lines |
| Base branch ref unclear | Try `symbolic-ref refs/remotes/origin/HEAD` and common `origin/main` / `origin/master`; then ask the user which ref to use for `git show` |
| Auth error | Suggest `/endor-setup` |
| MCP not available | Suggest `/endor-setup` to configure |
