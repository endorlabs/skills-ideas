# Security Hooks

Deterministic enforcement layer for Endor Labs security skills. Unlike rules (advisory) and skills (user-invoked), hooks are **guaranteed to run** every time their event fires.

## How Hooks Work

Hooks are shell scripts that execute at specific points in Claude Code's lifecycle:

| Exit Code | Behavior |
|-----------|----------|
| `exit 0` + no output | Silent allow — nothing happens |
| `exit 0` + stdout | Allow, inject stdout into Claude's context |
| `exit 2` + stderr | **BLOCK** the action with stderr as the reason |

Hooks receive JSON on stdin with session, tool, and input context.

## Hook Inventory

### Tier 1: Hard Blocks (exit 2)

These hooks **prevent** dangerous actions. They cannot be bypassed by Claude.

| Hook | Event | What It Blocks |
|------|-------|----------------|
| `protect-files.sh` | PreToolUse → Edit\|Write | Edits to `.env`, `.pem`, `.key`, `credentials.json`, `.netrc`, `.npmrc` |

### Tier 2: Warnings + Required Action (exit 0, imperative stdout)

These hooks **warn** about issues and inject mandatory action reminders into Claude's context.

| Hook | Event | What It Detects | Skills Triggered |
|------|-------|-----------------|------------------|
| `warn-secrets-at-write.sh` | PreToolUse → Edit\|Write | Secret patterns in content being written (before file save) | `/endor-secrets` |
| `warn-insecure-code.sh` | PreToolUse → Edit\|Write | Dangerous code patterns: dynamic code execution, innerHTML assignment, SQL concatenation, shell injection, unsafe deserialization | `/endor-sast` |
| `check-dep-install.sh` | PostToolUse → Bash | Dependency install commands (npm, pip, cargo, go, gem, etc.) | `/endor-check` |
| `check-manifest-edit.sh` | PostToolUse → Edit\|Write | Edits to dependency manifest files (package.json, requirements.txt, etc.) | `/endor-check` |
| `session-review-reminder.sh` | Stop | Security-sensitive files modified without review | `/endor-review` |

### Tier 3: Suggestions (exit 0, informational stdout)

These hooks **suggest** relevant skills without requiring action.

| Hook | Event | What It Detects | Skills Suggested |
|------|-------|-----------------|------------------|
| `suggest-container-review.sh` | PostToolUse → Edit\|Write | Dockerfile/compose edits; inline warns on `:latest`, no `USER`, `EXPOSE 22`, `privileged: true`, docker.sock | `/endor-container` |
| `suggest-cicd-review.sh` | PostToolUse → Edit\|Write | CI/CD config edits; warns on unpinned actions, hardcoded secrets, `write-all` perms | `/endor-cicd` |
| `suggest-sast-review.sh` | PostToolUse → Edit\|Write | Code handling API endpoints, auth, SQL, file I/O, user input | `/endor-sast` |
| `warn-iac-patterns.sh` | PostToolUse → Edit\|Write | Terraform/CloudFormation/K8s anti-patterns (public S3, IAM wildcards, privileged pods) | Manual review |
| `suggest-license-check.sh` | PostToolUse → Bash | Dependency installs (parallel to `check-dep-install.sh`) | `/endor-license` |
| `post-scan-routing.sh` | PostToolUse → MCP scan | Scan completion — routes to findings/fix workflow | `/endor-findings`, `/endor-fix` |
| `mcp-error-recovery.sh` | PostToolUse → MCP `*` | Auth errors, scan failures, namespace issues | `/endor-setup`, `/endor-troubleshoot` |
| `detect-pr-intent.sh` | UserPromptSubmit | PR/merge/push intent in user prompt | `/endor-review` |
| `suggest-endor-tools.sh` | UserPromptSubmit | CVE IDs, package safety questions, demo requests, setup questions | `/endor-explain`, `/endor-score`, `/endor-demo`, `/endor-setup` |
| `session-security-posture.sh` | SessionStart | Session start/compaction — injects security posture and re-injects lost context | Informational |

### Silent (no output)

| Hook | Event | What It Does |
|------|-------|-------------|
| `track-security-files.sh` | PostToolUse → Edit\|Write | Records security-sensitive file modifications to session state for `session-review-reminder.sh` |

## Event Flow

```
User types message
    │
    ├─ UserPromptSubmit
    │  ├─ detect-pr-intent.sh ......... remind /endor-review if PR intent
    │  └─ suggest-endor-tools.sh ...... suggest skills for CVEs, packages, etc.
    │
    ├─ SessionStart (startup | compact)
    │  └─ session-security-posture.sh . inject posture summary, re-inject on compact
    │
    ├─ PreToolUse (Edit|Write)
    │  ├─ protect-files.sh ............ BLOCK .env, .pem, credentials
    │  ├─ warn-secrets-at-write.sh .... warn on secret patterns in content
    │  └─ warn-insecure-code.sh ....... warn on insecure code patterns
    │
    │  ── Tool Executes ──
    │
    ├─ PostToolUse (Edit|Write)
    │  ├─ check-manifest-edit.sh ...... remind /endor-check for manifests
    │  ├─ suggest-container-review.sh . suggest /endor-container, inline warnings
    │  ├─ suggest-cicd-review.sh ...... suggest /endor-cicd, inline warnings
    │  ├─ suggest-sast-review.sh ...... suggest /endor-sast for security code
    │  ├─ warn-iac-patterns.sh ........ warn on IaC anti-patterns
    │  └─ track-security-files.sh ..... (silent) track modifications
    │
    ├─ PostToolUse (Bash)
    │  ├─ check-dep-install.sh ........ remind /endor-check for dep installs
    │  └─ suggest-license-check.sh .... remind /endor-license alongside
    │
    ├─ PostToolUse (MCP scan)
    │  └─ post-scan-routing.sh ........ route: scan → findings → fix
    │
    ├─ PostToolUse (MCP *)
    │  └─ mcp-error-recovery.sh ....... route errors to setup/troubleshoot
    │
    └─ Stop
       └─ session-review-reminder.sh .. final review reminder, cleanup
```

## Testing

Every hook can be tested by piping JSON to stdin. See the header comment of each script for a specific test command. General pattern:

```bash
# Pipe JSON matching the hook's expected input format
echo '{"tool_name":"Edit","tool_input":{"file_path":"config.js","new_string":"..."}}' \
  | .claude/hooks/<hook-name>.sh

# Check the exit code
echo $?
# 0 = allowed (with or without context injection)
# 2 = blocked
```

Key test scenarios:

```bash
# Secret detection (warn-secrets-at-write.sh)
echo '{"tool_name":"Edit","tool_input":{"file_path":"c.js","new_string":"key=AKIAIOSFODNN7EXAMPLE"}}' \
  | .claude/hooks/warn-secrets-at-write.sh

# Container review (suggest-container-review.sh)
echo '{"tool_name":"Write","tool_input":{"file_path":"Dockerfile","content":"FROM node:latest"},"cwd":"/tmp"}' \
  | .claude/hooks/suggest-container-review.sh

# IaC patterns (warn-iac-patterns.sh)
echo '{"tool_name":"Write","tool_input":{"file_path":"main.tf","content":"acl = public-read"},"cwd":"/tmp"}' \
  | .claude/hooks/warn-iac-patterns.sh

# CVE mention (suggest-endor-tools.sh)
echo '{"prompt":"What is CVE-2024-38816?"}' \
  | .claude/hooks/suggest-endor-tools.sh

# MCP error recovery (mcp-error-recovery.sh)
echo '{"tool_name":"mcp__endor-cli-tools__scan","tool_error":"auth failed"}' \
  | .claude/hooks/mcp-error-recovery.sh

# License check (suggest-license-check.sh)
echo '{"tool_name":"Bash","tool_input":{"command":"npm install lodash"}}' \
  | .claude/hooks/suggest-license-check.sh

# Session tracking + review reminder
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/login.js"},"session_id":"t1"}' \
  | .claude/hooks/track-security-files.sh
echo '{"hook_event_name":"Stop","session_id":"t1"}' \
  | .claude/hooks/session-review-reminder.sh
```

## Design Principles

1. **Fast exit when irrelevant.** Every hook checks in the first few lines whether it applies. Non-matching cases exit in under 20ms.
2. **Stderr for blocks, stdout for context.** Getting this backwards breaks the contract.
3. **Chain to skills, not to scans.** Hooks say "run /endor-sast" not "scan for SQL injection." The skill knows how to scan.
4. **Block messages are actionable.** Every block explains WHY and provides a clear path forward.
5. **No duplication.** Each hook covers a distinct concern. Related hooks complement rather than overlap.
6. **Portable.** Scripts require only `bash`, `jq`, and `grep`.

## Session State

Hooks that track state across tool calls use temp files scoped by session ID:

```
/tmp/claude-security-{SESSION_ID}
```

- Written by: `track-security-files.sh` (appends modified file paths)
- Read by: `session-review-reminder.sh` (checks if review is needed)
- Read by: `session-security-posture.sh` (reports modified file count)
- Cleaned up by: `session-review-reminder.sh` (on Stop event)

## Adding a New Hook

1. Create a script in `.claude/hooks/` with a descriptive header comment
2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. Wire it in `.claude/settings.json` under the appropriate event and matcher
4. Test with pipe (see Testing section above)
5. Verify exit code: `echo $?`
6. Classify by tier: Block (exit 2), Warn (exit 0 + imperative), or Suggest (exit 0 + informational)
