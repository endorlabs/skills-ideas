# Security Hooks

Routing layer for Endor Labs security skills. Hooks detect the right moment to invoke an Endor Labs skill and inject reminders into Claude's context.

## How Hooks Work

Hooks are shell scripts that execute at specific points in Claude Code's lifecycle:

| Exit Code | Behavior |
|-----------|----------|
| `exit 0` + no output | Silent allow — nothing happens |
| `exit 0` + stdout | Allow, inject stdout into Claude's context |
| `exit 2` + stderr | **BLOCK** the action with stderr as the reason |

Hooks receive JSON on stdin with session, tool, and input context.

## Hook Inventory

| Hook | Event | What It Does | Endor Skill |
|------|-------|--------------|-------------|
| `check-dep-install.sh` | PostToolUse → Bash | Detects dependency install commands | `/endor-check` |
| `check-manifest-edit.sh` | PostToolUse → Edit\|Write | Detects edits to dependency manifest files | `/endor-check` |
| `suggest-license-check.sh` | PostToolUse → Bash | Suggests license check after dep installs | `/endor-license` |
| `post-scan-routing.sh` | PostToolUse → MCP scan | Routes scan results to findings/fix workflow | `/endor-findings`, `/endor-fix` |
| `mcp-error-recovery.sh` | PostToolUse → MCP `*` | Handles auth errors, scan failures | `/endor-setup`, `/endor-troubleshoot` |
| `detect-pr-intent.sh` | UserPromptSubmit | Detects PR/merge/push intent in prompt | `/endor-review` |
| `suggest-endor-tools.sh` | UserPromptSubmit | CVEs, package safety, GitHub Actions workflow prompts | `/endor-explain`, `/endor-score`, `/endor-demo`, `/endor-ghactions` |
| `session-review-reminder.sh` | Stop | Reminds to review if sensitive files changed | `/endor-review` |

## Event Flow

```
User types message
    │
    ├─ UserPromptSubmit
    │  ├─ detect-pr-intent.sh ......... remind /endor-review if PR intent
    │  └─ suggest-endor-tools.sh ...... suggest skills for CVEs, packages, etc.
    │
    │  ── Tool Executes ──
    │
    ├─ PostToolUse (Edit|Write)
    │  └─ check-manifest-edit.sh ...... remind /endor-check for manifests
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

Every hook can be tested by piping JSON to stdin:

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"config.js","new_string":"..."}}' \
  | .claude/hooks/<hook-name>.sh

echo $?
# 0 = allowed (with or without context injection)
# 2 = blocked
```

Key test scenarios:

```bash
# Dep install detection (check-dep-install.sh)
echo '{"tool_name":"Bash","tool_input":{"command":"npm install lodash"}}' \
  | .claude/hooks/check-dep-install.sh

# CVE mention (suggest-endor-tools.sh)
echo '{"prompt":"What is CVE-2024-38816?"}' \
  | .claude/hooks/suggest-endor-tools.sh

# MCP error recovery (mcp-error-recovery.sh)
echo '{"tool_name":"mcp__endor-cli-tools__scan","tool_error":"auth failed"}' \
  | .claude/hooks/mcp-error-recovery.sh

# License check (suggest-license-check.sh)
echo '{"tool_name":"Bash","tool_input":{"command":"npm install lodash"}}' \
  | .claude/hooks/suggest-license-check.sh

# Session review reminder
echo '{"hook_event_name":"Stop","session_id":"t1"}' \
  | .claude/hooks/session-review-reminder.sh
```

## Design Principles

1. **Fast exit when irrelevant.** Every hook checks in the first few lines whether it applies. Non-matching cases exit in under 20ms.
2. **Stderr for blocks, stdout for context.** Getting this backwards breaks the contract.
3. **Chain to skills, not to scans.** Hooks say "run /endor-sast" not "scan for SQL injection." The skill knows how to scan.
4. **No duplication.** Each hook covers a distinct concern.
5. **Portable.** Scripts require only `bash`, `jq`, and `grep`.

## Adding a New Hook

1. Create a script in `.claude/hooks/` with a descriptive header comment
2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. Wire it in `.claude/settings.json` under the appropriate event and matcher
4. Test with pipe (see Testing section above)
5. Verify exit code: `echo $?`
