# Prompt: Generate Claude Code Hooks for Endor Labs Security Skills

## Instructions for the LLM

You are an experienced Application Security Engineer who has spent years embedding security into developer workflows. You understand that security tooling only works when developers actually use it — which means it must be fast, non-disruptive, and genuinely helpful rather than annoying. You've seen what happens when security gates are too aggressive (developers disable them) and when they're too passive (vulnerabilities ship to production).

Your task is to design and implement a comprehensive set of **Claude Code hooks** that act as a deterministic enforcement layer for an existing suite of Endor Labs security skills. The hooks guarantee that security checks happen at the right moments — every time, without exception — while the skills provide the intelligence to actually perform those checks.

**Your design philosophy:**
- **Secure by default, escapable by intent.** Block dangerous actions automatically, but never trap the developer. Every block message should explain WHY and offer a clear path forward.
- **Fast and silent when nothing is wrong.** A hook that adds latency to every tool call but rarely fires is a bad hook. Check quickly, exit early, output nothing when there's no issue.
- **Precise over broad.** A hook that fires on every Bash command but only cares about 3% of them creates noise. Use matchers and early-exit patterns to minimize false triggers.
- **Complement, don't duplicate.** Skills already exist for deep analysis. Hooks should detect the MOMENT to invoke a skill, not replicate the skill's logic. Inject a reminder, don't perform the scan.
- **Developer context matters.** A `git push` to a feature branch is different from a `git push` to `main`. A `pip install` in a virtualenv during prototyping is different from editing `requirements.txt` for production. Where possible, use context to calibrate the response (warn vs. block vs. silent).

---

## What Are Claude Code Hooks?

Hooks are shell scripts, HTTP endpoints, or LLM prompts that execute **deterministically** at specific points in Claude Code's lifecycle. Unlike skills (which Claude follows as instructions) and rules (which are advisory), hooks are **guaranteed to run** every time their event fires.

### Hook Events Available

| Event | When It Fires | What Hooks Can Do |
|-------|---------------|-------------------|
| `PreToolUse` | Before a tool executes | Block (exit 2), allow (exit 0), inject context (stdout) |
| `PostToolUse` | After a tool succeeds | Inject context (stdout), log actions |
| `UserPromptSubmit` | Before Claude processes user input | Inject additional context (stdout), modify behavior |
| `Stop` | When Claude finishes responding | Block completion (exit 2) to force additional work |
| `SessionStart` | Session begins or resumes | Inject context, set environment |
| `Notification` | Claude needs user input/permission | Send desktop alerts |
| `SubagentStart` | Subagent spawned | Track delegation |
| `SubagentStop` | Subagent finishes | Aggregate results |

### Hook Configuration Format

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "regex pattern matching tool name or event source",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/my-script.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook Input/Output Contract

**Input:** Hooks receive JSON on stdin with:
```json
{
  "session_id": "abc123",
  "cwd": "/path/to/project",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm install lodash" }
}
```

**Output:**
- **Exit 0, no stdout** → Silent allow (nothing happens)
- **Exit 0, with stdout** → Allow, and inject stdout text into Claude's context as a `<user-prompt-submit-hook>` message
- **Exit 2, with stderr** → **BLOCK** the action. Claude receives the stderr text as feedback explaining why.
- **Other exit codes** → Allow, log stderr for debugging

### Matchers

Matchers are regex patterns that filter WHEN a hook fires:
- `PreToolUse` / `PostToolUse` matchers filter on **tool name**: `Bash`, `Edit`, `Write`, `Read`, `Glob`, `Grep`, `mcp__endor-cli-tools__.*`
- `UserPromptSubmit` matcher is typically empty (`""`) to match all prompts
- `SessionStart` matcher filters on **source**: `startup`, `resume`, `clear`, `compact`

### Script Best Practices

```bash
#!/usr/bin/env bash
set -euo pipefail

# Always read stdin first (hook input is JSON)
INPUT=$(cat)

# Parse with jq
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# EXIT EARLY when this hook doesn't apply
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Do your check...

# To BLOCK: write reason to stderr, exit 2
echo "BLOCKED: reason here" >&2
exit 2

# To INJECT CONTEXT: write message to stdout, exit 0
echo "[HOOK: Context Message] details here"
exit 0

# To SILENTLY ALLOW: just exit 0 with no output
exit 0
```

---

## The Endor Labs Skills Ecosystem

Below is the complete catalog of security skills that your hooks should complement. Each skill is a Claude Code slash command that provides deep security analysis. Your hooks should detect the RIGHT MOMENT to invoke these skills and inject reminders into Claude's context.

### Implemented Skills (Production)

| Skill | Trigger | What It Does | MCP Tools Used |
|-------|---------|-------------|----------------|
| `/endor-check` | check dependency, check package, is this package safe | Check a specific dependency version for known vulnerabilities | `check_dependency_for_vulnerabilities` |
| `/endor-fix` | fix vulnerability, fix cve, remediate finding | Find safe upgrade paths and apply fixes | `get_resource` (Finding), delegates to `/endor-upgrade-impact` |
| `/endor-review` | pre-pr review, security review, ready to merge | Full pre-PR security gate: deps, SAST, secrets, licenses, containers | `scan` (pr_incremental), `check_dependency_for_vulnerabilities` |
| `/endor-api` | custom query, raw api, direct api | Execute custom queries against Endor Labs API | All MCP tools |
| `/endor-upgrade-impact` | upgrade impact, breaking changes, should I upgrade | Analyze upgrade risk using pre-computed change impact data | `get_resource` (Project, VersionUpgrade) |

### Planned Skills (In Development)

| Skill | Trigger | What It Does |
|-------|---------|-------------|
| `/endor` | endor, security scan, vulnerability | Main router — detects intent and routes to specialized skill |
| `/endor-scan` | quick scan, security scan, scan repo | Fast security scan (seconds) |
| `/endor-scan-full` | full scan, deep scan, reachability scan | Comprehensive scan with call graph reachability analysis |
| `/endor-findings` | show findings, list vulnerabilities | Display security findings with filtering |
| `/endor-explain` | explain cve, what is cve, vulnerability details | Detailed CVE/finding explanation |
| `/endor-score` | package score, package health, evaluate package | Health scores for open source packages |
| `/endor-sca` | sca scan, dependency scan, vulnerable packages | Software composition analysis |
| `/endor-sast` | static analysis, code vulnerabilities, sql injection | Static application security testing |
| `/endor-secrets` | scan secrets, find secrets, exposed credentials | Secrets and credential detection |
| `/endor-license` | license check, license compliance, copyleft | License compliance analysis |
| `/endor-container` | container scan, docker scan, dockerfile scan | Container image and Dockerfile analysis |
| `/endor-sbom` | sbom export, software bill of materials | SBOM generation and analysis |
| `/endor-cicd` | endor ci, github actions endor, security pipeline | Generate CI/CD security pipeline configs |
| `/endor-policy` | security policy, create policy, block critical | Security policy management |
| `/endor-setup` | endor setup, endor configure, endor auth | First-time onboarding wizard |
| `/endor-demo` | endor demo, try endor, demo security scan | Demo mode with simulated data |
| `/endor-help` | endor help, endor commands | Command reference |
| `/endor-troubleshoot` | troubleshoot, scan error, scan failed | Diagnose and fix scan failures |

### Existing Rules (Advisory)

These rules are instructions Claude *should* follow but are not guaranteed:

| Rule | What It Does |
|------|-------------|
| `endor-prevent.md` | After every tool use, check if dependencies were installed/modified and run `/endor-check` |
| `dependency-security.md` | Check new/updated dependencies for vulnerabilities |
| `secrets-detection.md` | Scan for hardcoded credentials in config/code files |
| `sast-analysis.md` | Detect code vulnerabilities (SQLi, XSS, command injection) |
| `license-compliance.md` | Check license compatibility when adding dependencies |
| `container-security.md` | Analyze Dockerfiles and docker-compose for security issues |
| `pr-security-review.md` | Comprehensive pre-PR security gate |

### Available MCP Tools

These are the tools available through the Endor Labs MCP server (`mcp__endor-cli-tools__*`):

| MCP Tool | Purpose |
|----------|---------|
| `scan` | Scan repository for vulnerabilities, secrets, SAST, dependencies, GitHub Actions |
| `check_dependency_for_vulnerabilities` | Check specific package+version for known CVEs |
| `check_dependency_for_risks` | Broader risk check including vulnerabilities AND malware detection |
| `get_endor_vulnerability` | Get detailed info about a CVE or GHSA |
| `get_resource` | Retrieve any Endor Labs resource (Project, Finding, PackageVersion, Metric, etc.) |
| `security_review` | Analyze code diffs (staged + unstaged vs HEAD, or main vs last commit). Enterprise Edition only. |

**Note:** `check_dependency_for_risks` is a superset of `check_dependency_for_vulnerabilities` — it also detects malware. Consider using it where available. The `security_review` tool is Enterprise-only and performs AI-powered security review on code diffs — this is particularly relevant for hooks that trigger on git commit or PR creation workflows.

---

## Existing Hooks (Already Built)

The following hooks have already been implemented. Do NOT recreate these — build new hooks that complement them.

### 1. check-dep-install.sh (PostToolUse → Bash)
Detects dependency install commands (`npm install`, `pip install`, `go get`, `cargo add`, etc.) and injects a reminder to run `/endor-check`.

### 2. check-manifest-edit.sh (PostToolUse → Edit|Write)
Detects edits to manifest files (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, etc.) and injects a reminder to run `/endor-check`.

### 3. suggest-license-check.sh (PostToolUse → Bash)
Suggests `/endor-license` after dependency installs (parallel to `check-dep-install.sh`).

### 4. post-scan-routing.sh (PostToolUse → MCP scan)
Routes scan results to `/endor-findings` and `/endor-fix` workflow.

### 5. mcp-error-recovery.sh (PostToolUse → MCP *)
Handles auth errors, scan failures, and namespace issues — routes to `/endor-setup` or `/endor-troubleshoot`.

### 6. detect-pr-intent.sh (UserPromptSubmit)
Detects PR/merge/push intent in user prompts and injects a reminder to run `/endor-review`.

### 7. suggest-endor-tools.sh (UserPromptSubmit)
Detects CVE IDs, package safety questions, demo requests, and setup questions — routes to relevant `/endor-*` skills.

### 8. session-review-reminder.sh (Stop)
Reminds to run `/endor-review` if security-sensitive files were modified during the session.

---

## Your Task

Design and implement **new hooks** that route to Endor Labs skills at the right moments. Hooks should ONLY detect when to invoke an Endor Labs skill — they must NOT perform their own security scanning or pattern detection. All security analysis should be delegated to the appropriate `/endor-*` skill or MCP tool.

### Category 1: Cross-Skill Orchestration (Workflow Chaining)

These hooks connect skills into workflows. When one skill's output implies the need for another skill, the hook bridges that gap.

**Post-Scan Finding Routing**
- After `scan` MCP tool completes (PostToolUse on `mcp__endor-cli-tools__scan`), if findings exist, inject: "Run `/endor-findings` to review results, or `/endor-fix {top-cve}` for the most critical finding."
- This creates the natural workflow: scan → findings → fix.

**Dependency Install → Parallel Checks**
- When a dependency is installed, the current hook triggers `/endor-check`. But the ideal workflow is: install → `/endor-check` + `/endor-license` in parallel → if vulnerable, suggest `/endor-fix` → if license issue, suggest alternative.
- Consider combining the vuln check and license check into a single hook message that asks Claude to run both.

**Post-Fix Verification**
- After Claude edits a manifest file to fix a vulnerability (detected via file path + context like "upgrading" or "fixing" in recent conversation), inject a reminder to re-run `/endor-check` to verify the fix worked.

**Auth Failure → Setup**
- When any MCP tool call fails (PostToolUseFailure on `mcp__endor-cli-tools__.*`), detect auth-related errors and inject a suggestion to run `/endor-setup`.
- When scan errors occur that match known patterns (build failures, missing toolchains), suggest `/endor-troubleshoot`.

### Category 2: Session-Level Security Posture

These hooks maintain security awareness across the entire session lifecycle.

**Session Start Context**
- When a session starts (`SessionStart`, `matcher: "startup"`), check if a `.endor/` cache directory exists with recent scan results. If found, inject a brief security posture summary: "Last scan: {date}. Open critical findings: {count}."
- When context is compacted (`SessionStart`, `matcher: "compact"`), re-inject the security posture and any critical reminders that may have been lost.

**Session-Level File Tracking**
- Track which security-sensitive files were modified during the session by writing to a temp file (e.g., `/tmp/claude-security-session-$SESSION_ID`).
- On `Stop` event, check if security-sensitive files were modified without a corresponding security review. If so, inject: "Security-sensitive files were modified this session. Run `/endor-review` before creating a PR."

**Post-Session Cleanup**
- On `SessionEnd`, clean up any temp state files created by session-tracking hooks.

### Category 3: Developer Experience (Making Security Frictionless)

These hooks improve the developer experience around security tooling, making it feel helpful rather than obstructive.

**Contextual Skill Suggestions**
- When the user's prompt mentions a CVE ID (pattern: `CVE-\d{4}-\d+`) but doesn't invoke `/endor-explain`, inject a suggestion: "Want details? Run `/endor-explain {cve-id}`."
- When the user asks about a package's safety or reputation but doesn't invoke `/endor-score`, suggest it.
- When the user mentions "demo" or "try" in the context of Endor Labs, suggest `/endor-demo`.

**Scan Result Summaries**
- After a successful full scan (PostToolUse on `mcp__endor-cli-tools__scan`), if zero critical findings, inject a brief positive confirmation: "Scan complete — no critical issues found." Don't make the developer hunt through output to confirm a clean result.

**Error Recovery**
- When Claude runs a Bash command that fails and the error output contains patterns like "endorctl", "ENDOR_", "MCP", "auth", "token", "namespace" — suggest `/endor-troubleshoot` or `/endor-setup` as appropriate.

### Design Constraints

1. **Performance:** Every hook adds latency. Scripts should exit in <100ms for the common case (no match). Use early-exit patterns aggressively.
2. **No duplication:** Don't recreate existing hook logic. Reference existing hooks as patterns.
3. **Portable:** Scripts must work on Linux/macOS with `bash`, `jq`, and `grep`. No exotic dependencies.
4. **Testable:** Each script should be testable by piping JSON to stdin: `echo '{"tool_name":"Bash","tool_input":{"command":"..."}}' | .claude/hooks/my-hook.sh`
5. **Self-documenting:** Each script should have a header comment explaining what it does, when it fires, and its exit code behavior.

### Output Format

For each hook, provide:

1. **The script file** (`.claude/hooks/hook-name.sh`) with proper header comments
2. **The settings.json entry** showing how to wire it up
3. **A brief explanation** of what gap it fills and which skills it complements
4. **Test commands** showing how to verify it works

At the end, provide the complete updated `settings.json` with ALL hooks (existing + new) wired up.

---

## Tips for Excellent Hook Design

1. **Parse, don't regex the whole command.** `jq` is your friend. Extract `.tool_input.command` or `.tool_input.file_path` first, THEN pattern match on the extracted value.

2. **Use stderr for block messages, stdout for context injection.** This is the fundamental output contract. Getting it backwards means blocks silently pass and context messages appear as errors.

3. **Keep block messages actionable.** Bad: "BLOCKED: Security violation." Good: "BLOCKED: Detected AWS access key (AKIA...) in staged file config/aws.js:14. Remove the key and use AWS_ACCESS_KEY_ID environment variable instead. Run /endor-secrets for a full scan."

4. **Context injection messages should be imperative.** The message goes into Claude's context as if the user said it. Write it as a clear instruction: "You MUST now run /endor-check for package lodash@4.17.20" not "A dependency was installed, you might want to check it."

5. **Matchers reduce noise.** If your hook only cares about Bash commands, use `"matcher": "Bash"` — don't match all tools and filter in the script. The matcher prevents the script from even being invoked.

6. **Think about the false positive cost.** A hook that blocks a legitimate `git push` is worse than a hook that misses a rare edge case. When in doubt, warn (inject context) rather than block (exit 2).

7. **Consider context compaction.** Claude's context window fills up and gets compacted. Critical security state injected by SessionStart hooks may be lost. Use the `"matcher": "compact"` on SessionStart to re-inject after compaction.

8. **Chain hooks to skills, not to scans.** A hook should say "run /endor-sast" not "scan for SQL injection." The skill knows how to scan properly. The hook just knows WHEN to scan.

9. **Hooks can't read previous tool results.** Each hook invocation is stateless. If you need to track state across tool calls (e.g., "were any security-sensitive files modified this session?"), write state to a temp file.

10. **Test with pipe.** Every hook should be testable:
    ```bash
    echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' | .claude/hooks/my-hook.sh
    echo $?  # Check exit code
    ```

11. **Use `check_dependency_for_risks` over `check_dependency_for_vulnerabilities` where possible.** The `_risks` variant also detects malware, not just known CVEs. Skills that only reference `_vulnerabilities` are leaving malware detection on the table.

12. **Leverage `security_review` for PR workflows (Enterprise).** If the user has Enterprise Edition, the `security_review` MCP tool performs AI-powered security analysis on code diffs. For hooks that fire on PR/commit intent, check if Enterprise features are available and suggest `security_review` as a more thorough alternative to manual SAST + secrets + dep checks.

13. **Don't over-inject.** If Claude is already running a security skill (e.g., the user typed `/endor-review`), hooks should NOT also inject reminders to run security checks. Check the prompt or recent context for skill invocations before injecting.

14. **Categorize hooks by severity tier.** Not all hooks are equal:
    - **Tier 1 (Warn + Require Action):** Dependency installs without checks, PR creation without review — inject imperative reminders.
    - **Tier 2 (Suggest):** CVE mentioned without `/endor-explain`, package discussed without `/endor-score` — gentle suggestions that Claude can act on or skip.

15. **Consider the `PostToolUseFailure` event.** This fires when a tool FAILS, not when it succeeds. This is the perfect event for error recovery hooks: detect MCP auth failures, scan timeouts, or CLI errors, and route to `/endor-setup` or `/endor-troubleshoot`.

---

## Advanced Considerations

### MCP Tool Matching

The Endor Labs MCP tools use the naming pattern `mcp__endor-cli-tools__<tool_name>`. You can match all Endor tools with:
```json
{ "matcher": "mcp__endor-cli-tools__.*" }
```

Or match specific tools:
```json
{ "matcher": "mcp__endor-cli-tools__scan" }
```

This is critical for Category 3 (Cross-Skill Orchestration) hooks — you can fire hooks specifically after scan results, after dependency checks, or after any Endor tool call fails.

### State Management Across Hook Invocations

Hooks are stateless per invocation. For session-level tracking (Category 4), use temp files:

```bash
STATE_FILE="/tmp/claude-security-${SESSION_ID:-$$}"

# Write state (PostToolUse hook)
echo "$FILE_PATH" >> "$STATE_FILE"

# Read state (Stop hook)
if [[ -f "$STATE_FILE" ]]; then
  MODIFIED_FILES=$(cat "$STATE_FILE")
  # Check if security review was done...
fi
```

Use `$SESSION_ID` from the hook input JSON (`.session_id`) to scope state per session.

### Hook Composition Pattern

Multiple hooks can fire on the same event. Use this to compose focused hooks rather than building monolithic scripts:

```json
{
  "PostToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": ".claude/hooks/check-dep-install.sh" },
        { "type": "command", "command": ".claude/hooks/check-license-on-install.sh" }
      ]
    }
  ]
}
```

Both hooks run sequentially. If the first outputs a reminder, the second can add to it. This keeps scripts focused and testable.

### Avoiding Noise: The Frequency/Value Matrix

Before creating a hook, plot it on this matrix:

```
                    HIGH VALUE
                        |
         Tier 1 Blocks  |  Tier 2 Requires
         (secrets in    |  (dep checks on
          commits)      |   install)
                        |
LOW FREQ ———————————————+——————————————— HIGH FREQ
                        |
         Tier 3 Suggest |  DANGER ZONE
         (CVE mentions) |  (avoid: fires
                        |   constantly, low
                        |   value per fire)
                        |
                    LOW VALUE
```

Hooks in the DANGER ZONE (high frequency, low value) will annoy developers. If a hook fires on every `Edit` but only matters 5% of the time, it should be silent (no output) for the 95% case and fast (<50ms to exit).
