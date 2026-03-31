---
name: endor-ai-sast
description: >
  Fetch and display AI-powered SAST findings from the Endor Labs platform. Use when the
  user says "AI SAST results", "AI SAST findings", "AI static analysis", "endor ai sast",
  "show AI SAST", or wants to view pre-computed AI-driven code security findings. Do NOT
  use for running a new SAST scan (/endor-sast), viewing general findings (/endor-findings),
  or explaining a specific CVE (/endor-explain).
---

# Endor Labs AI SAST Analysis

Fetch AI-powered static analysis security findings using pre-computed data from the Endor Labs platform.

## Prerequisites

- Endor Labs authenticated (run `/endor-setup` if not)

## Workflow

### Step 1: Resolve Namespace

Before making ANY `endorctl api` call, resolve the namespace.

```bash
export ENDOR_NAMESPACE="${ENDOR_NAMESPACE:-$(grep -E '^ENDOR_NAMESPACE:' ~/.endorctl/config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')}"
echo "ENDOR_NAMESPACE=$ENDOR_NAMESPACE"
```

If empty, run `/endor-setup` to authenticate and set the namespace.

### Step 2: Find the Project UUID

Get the git remote URL, normalize it to HTTPS format, then query for the project. **Only run this after Step 1 succeeds.**

```bash
RAW_URL=$(git remote get-url origin 2>/dev/null)
# Normalize SSH URLs (git@github.com:org/repo.git) to HTTPS (https://github.com/org/repo.git)
if echo "$RAW_URL" | grep -q '^git@'; then
  GIT_URL="https://$(echo "$RAW_URL" | sed 's|^git@||; s|:|/|')"
else
  GIT_URL="$RAW_URL"
fi
npx -y endorctl api list --resource Project -n $ENDOR_NAMESPACE \
  --filter "spec.git.http_clone_url=='$GIT_URL'" \
  --field-mask="uuid,meta.name" 2>&1 | tee /tmp/endor_list_project_output.txt
```

For CLI field paths and parsing gotchas, read references/cli-parsing.md.

Run this command ONCE with the normalized URL. Do NOT retry with URL variations. If the project is not found, see Error Handling.

### Step 3: Fetch AI SAST Findings

```bash
npx -y endorctl api list -r Finding -n $ENDOR_NAMESPACE \
  -f 'context.type == CONTEXT_TYPE_MAIN and spec.project_uuid == "{PROJECT_UUID}" and spec.method == SYSTEM_EVALUATION_METHOD_DEFINITION_AI_SAST' \
  --field-mask meta.description,spec.explanation,spec.dependency_file_paths,spec.level \
  2>&1 | tee /tmp/endor_sast_findings_output.txt
```

If the output is empty, respond with exactly: `"No AI SAST findings are available for this project at this moment."` — no further explanation.

### Step 4: Present Results

Parse the results from Step 3 and present them using the **tiered output format** below. The goal is to answer "what should I worry about?" — not dump everything at once.

#### 4a: Severity Breakdown

Show a summary count table:

```
## AI SAST Findings Summary

| Severity | Count |
|----------|-------|
| Critical | X     |
| High     | X     |
| Medium   | X     |
| Low      | X     |
| **Total**| **X** |
```

#### 4b: Actionable Groups

Group findings by vulnerability type (using `meta.description`) and present as actionable clusters.

**Short titles:** Use concise names in the output, not full CWE descriptions. Map verbose `meta.description` values to short labels:

| `meta.description` contains | Short title |
|-----|------|
| SQL Command | SQL Injection |
| Cross-site Scripting / Web Page Generation | XSS |
| Code Injection / Generation of Code | Code Injection |
| Path Traversal / Pathname to a Restricted Directory | Path Traversal |
| Authorization Bypass Through User-Controlled Key | Authorization Bypass (IDOR) |
| Missing Authorization / Missing Authentication | Missing Auth |
| Sensitive Information into Log | Sensitive Info in Logs |
| Hard-coded Credentials / Hard-coded Cryptographic | Hard-coded Credentials |
| Cleartext Storage | Cleartext Storage |
| Cleartext Transmission | Cleartext Transmission |
| Exposure of Sensitive Information | Info Disclosure |
| XML External Entity | XXE |
| Server-Side Request Forgery | SSRF |
| NoSQL / MongoDB | NoSQL Injection |
| Cryptographic Signature / Password Hash | Weak Cryptography |
| Deserialization of Untrusted Data | Insecure Deserialization |
| Open Redirect / URL Redirection | Open Redirect |
| Rate Limit | Rate Limit Bypass |
| Privilege Management / Incorrect Authorization | Broken Access Control |
| Denial of Service / Resource Exhaustion / Resource Consumption | DoS |
| Improper Handling of Exceptional Conditions / NULL Pointer | Error Handling |
| Improper Input Validation | Input Validation |
| Business Logic | Business Logic Flaw |
| Unhandled.*Error / Unhandled.*Exception | Unhandled Error |
| Insecure Design | Insecure Design |
| Improper Verification | Improper Verification |
| (anything else) | Use the parenthesized short name if present, otherwise use the full title |

**Only show clusters with 2+ findings.** Sort by highest severity in the group, then by count descending. For each cluster show:

```
### Vulnerability Clusters

- **SQL Injection** (6 findings across 5 files) [Critical] — use parameterized queries across all SQL operations
- **XSS** (8 findings across 7 files) [Critical/High] — audit all uses of bypassSecurityTrustHtml and innerHTML
- **Authorization Bypass (IDOR)** (5 findings across 4 files) [High] — enforce server-side ownership checks in middleware
```

**Remediation suggestions:** Provide a specific, actionable remediation per cluster — not generic "review and remediate." Use the mapping below as a starting point, and tailor based on what `spec.explanation` reveals about root causes:

| Cluster | Remediation |
|---------|-------------|
| SQL Injection | use parameterized queries across all SQL operations |
| XSS | audit all uses of bypassSecurityTrustHtml and innerHTML; use Angular sanitization |
| Code Injection | remove eval/safeEval usage; use safe alternatives |
| Path Traversal | validate and canonicalize file paths; reject `..` sequences |
| Authorization Bypass (IDOR) | enforce server-side ownership checks in middleware |
| NoSQL Injection | use typed query builders; never concatenate user input into $where clauses |
| Missing Auth | add authentication/authorization middleware to exposed endpoints |
| Sensitive Info in Logs | sanitize error objects before logging; avoid console.log of raw errors |
| Hard-coded Credentials | move secrets to environment variables or a vault |
| Cleartext Storage / Transmission | use httpOnly secure cookies instead of localStorage |
| Info Disclosure | restrict endpoint access and filter sensitive fields from responses |
| SSRF | validate URL scheme and host against an allowlist before server-side fetch |
| XXE | disable external entity processing in XML parser configuration |
| Rate Limit Bypass | use trusted client IP (not X-Forwarded-For) or validate proxy headers |
| Open Redirect | validate redirect targets against an allowlist of trusted domains |
| Weak Cryptography | use bcrypt/scrypt for passwords; verify JWT signatures server-side |
| Insecure Deserialization | use safe loaders (e.g., yaml.safeLoad); validate input schema before parsing |
| DoS | add input size limits and validation before resource allocation |
| Broken Access Control | verify user roles/permissions server-side on every request |
| Error Handling | add null/undefined checks and error boundaries; validate assumptions before dereferencing |
| Input Validation | validate and sanitize all user-controlled input at system boundaries |
| Business Logic Flaw | add server-side validation for business rules; don't trust client-supplied IDs or amounts |
| Unhandled Error | wrap I/O operations in try/catch; handle missing files and failed calls gracefully |
| Insecure Design | enforce resource limits and validate contracts before processing |
| Improper Verification | verify signatures and integrity server-side; don't trust client-decoded tokens |

After the multi-finding clusters, add a single rollup line for all single-finding types:

```
- *+ N other finding types with 1 finding each (use drill-down to explore)*
```

Identify common root causes within each cluster and tailor the remediation suggestion accordingly. This turns many individual findings into a smaller number of action items.

#### 4c: Critical Findings Detail

Show a **compact one-line-per-finding table** for **Critical severity only** by default:

```
### Critical Findings

| # | Title | Location | Summary |
|---|-------|----------|---------|
```

- **Title**: short title (use the same short title mapping from Step 4b, not the full CWE description)
- **Location**: value of `spec.dependency_file_paths`
- **Summary**: one-sentence summary extracted from `spec.explanation` (everything after `## Summary`, truncated to the first sentence or ~150 characters)

Sort rows by vulnerability type (group related findings together).

**Title/summary cross-check:** If the `spec.explanation` summary clearly describes a different vulnerability class than `meta.description` suggests (e.g., `meta.description` says "SQL Injection" but the summary describes a MongoDB `$where` NoSQL injection), use the **summary-derived type** for the short title in the table. The summary is closer to the actual finding; `meta.description` can be a rough CWE category that doesn't match the specific issue.

**Do NOT include the Data Flow column in the default output.** Data flow is available on demand (see Step 4d).

#### 4d: Drill-Down Prompt

After presenting the default output, offer drill-down options:

```
---
**Want more detail?** Try:
- "Show all High findings"
- "Show data flow for finding #3"
- "Expand the SQL Injection cluster"
- "Show all findings in routes/login.ts"
```

When the user requests a drill-down, show the full detail for the requested findings including:

- **Title**: value of `meta.description` — copy verbatim
- **Finding Location**: value of `spec.dependency_file_paths`
- **Severity**: value of `spec.level`
- **Summary**: copy verbatim from `spec.explanation` — everything after `## Summary` up to (but not including) `## Data Flow`
- **Data Flow**: copy verbatim from `spec.explanation` — everything from `## Data Flow` to the end, including all Stage and Location fields

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| Auth error | Run `/endor-setup` |
| License/permission error | Inform user: "AI SAST requires an Endor Labs license. Visit [app.endorlabs.com](https://app.endorlabs.com) or contact your administrator." |
| Project not found | Run `/endor-scan` to onboard the project, then retry `/endor-ai-sast` |
| No findings | Show exact message: "No AI SAST findings are available for this project at this moment." |
