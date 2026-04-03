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

4. **Hydrate each finding** — For **each** finding UUID returned by `scan`, call **`get_resource`** with **`resource_type`: `Finding`** to obtain the **file path**, **type**, **severity**, **description**, and the **detected secret value** only as needed for step 5. Treat any raw secret material as **internal**: use it for base-branch comparison **only** — **never** repeat it in user-visible output.

5. **Filter against base (no secret bytes in Bash output)** — For each hydrated finding, let `<path>` be the repo-relative file path and `<secret>` be the same string the scanner reported (internal use only). **Never** run bare **`git show <base-ref>:<path>`** and let stdout reach the Bash tool: transcripts log that output and **will expose every line of the file**, including secrets.

   Use an **exit-code-only** check so the tool sees **no file body**:
   - Write **`<secret>`** to a **short-lived file** (e.g. `mktemp` under the repo’s **`.git/`**, mode `600`), then run:  
     **`git -C <absolute-repo-root> show <base-ref>:<path> 2>/dev/null | grep -qF -f <pattern-file>`**  
     (quote `<path>` if needed; `<base-ref>:<path>` must be a valid **`ref:path`** — not `:path` alone.)
   - **Immediately `rm -f <pattern-file>`** after the command (even on failure).
   - **Interpret `grep`’s exit status:** **`0`** → the secret string appears in that revision of the file → **omit** the finding (already on base). **Nonzero** → not present, or `git show` produced no data (e.g. path missing on base) → **keep** the finding.

   **Why a pattern file:** Putting **`<secret>`** directly in the Bash string often **logs the secret in the command line** in the UI. The file path in the command is much safer; still **never** `cat` or print that file in any logged step.

   Do **not** use **`git show`** for this step in any form that **prints** the blob to stdout without piping into **`grep -q`** / **`rg -q`** (or equivalent quiet matcher).

6. **Present** — In Step 2, report **only** findings **kept** after step 5. State clearly that the list is **new vs base `<base-ref>`** (the base branch for your current branch), not the full raw scan list.

**Default (non–pre-commit) scans** — For each finding UUID returned, use **`get_resource`** with **`resource_type`: `Finding`** before presenting details. No base-branch filtering unless the user asks for it.

CLI fallback:
```bash
npx -y endorctl scan --path $(pwd) --secrets --output-type summary
```

### Step 2: Present Results

**Do not expose secret values** — In chat, transcripts, and markdown, include **only**: **type**, **severity**, **description** (from the finding / scanner), and **location** (file path and line; add column/region if the API provides it). **Never** include: the literal secret, redacted “preview” slices of it, **`git show` (or any command) stdout/stderr that contains the file body**, or before/after code that would reveal it. Base-branch checks must use **quiet pipelines** (step 5). Describe remediation in **generic** terms (e.g. “move to `process.env.API_KEY`”) without pasting sensitive lines. See also **Safety** in `rules/endor-safety.md`.

If secrets found, lead with:
> **SECRETS DETECTED** - {count} exposed credentials found. Rotate immediately -- they may already be compromised if committed to version control.

For **pre-commit / staged-only** runs, `{count}` must be the number of findings **after** base-branch filtering (`git show` check). Include the **Compared to base** line below; omit it for full-repo scans.

```markdown
## Secrets Scan Results

**Path:** {scanned path} | **Secrets Found:** {count}

**Compared to base:** `<base-ref>` — only secrets not already present in that base branch’s version of each file *(pre-commit / staged-only)*

### Exposed Secrets

| # | Type | Severity | Description | Location |
|---|------|----------|-------------|----------|
| 1 | AWS Access Key | Critical | Exposed long-lived cloud credential | `config/aws.js:15` |

### Detail: {Finding #N}

**Location:** `{file_path}:{line}`  
**Type:** {secret_type}  
**Severity:** {severity}  
**Description:** {finding description / risk summary — no secret literal}

**Immediate Actions:**
1. Rotate this credential immediately (generate new, revoke old)
2. Replace with a reference to configuration or a secrets manager — do not paste the new value here
3. Check git history for prior commits that may have leaked the same material

**Remediation (no literals):**
{Brief generic steps only — e.g. which env var or secret store to use — **no** code blocks containing the old or new secret}

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
