#!/usr/bin/env bash
# =============================================================================
# Stop hook: Remind about security review if sensitive files were modified
# =============================================================================
# Reads the session tracking state (written by track-security-files.sh) and
# checks if security-sensitive files were modified without a corresponding
# security review. If so, injects a final reminder.
#
# Fires on: Stop
# Exit 0 + stdout = inject review reminder (blocks completion, forces one more turn)
# Exit 0 + no output = no sensitive files modified or review already done
#
# Test: STATE_FILE="/tmp/claude-security-test123" && echo "src/auth/login.js" > "$STATE_FILE" && echo '{"hook_event_name":"Stop","session_id":"test123","cwd":"/tmp"}' | .claude/hooks/session-review-reminder.sh && rm -f "$STATE_FILE"
# =============================================================================
set -euo pipefail

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[[ -z "$SESSION_ID" ]] && exit 0

STATE_FILE="/tmp/claude-security-${SESSION_ID}"

# No tracking file = no sensitive files modified
[[ ! -f "$STATE_FILE" ]] && exit 0

# Read and deduplicate tracked files
MODIFIED_FILES=$(sort -u "$STATE_FILE" 2>/dev/null || true)
FILE_COUNT=$(echo "$MODIFIED_FILES" | grep -c '.' 2>/dev/null || echo "0")

[[ "$FILE_COUNT" -eq 0 ]] && exit 0

# Check if /endor-review or /endor-scan was mentioned in recent context
# (We can't check this directly from a hook — we rely on the tracking)
# The reminder is always injected; Claude can note if review was already done.

# Build file summary (max 10 files shown)
FILE_SUMMARY=$(echo "$MODIFIED_FILES" | head -10)
if [[ "$FILE_COUNT" -gt 10 ]]; then
  FILE_SUMMARY="${FILE_SUMMARY}\n  ... and $((FILE_COUNT - 10)) more"
fi

cat <<EOF
[HOOK: Session Security Review Reminder]
$FILE_COUNT security-sensitive file(s) were modified this session:
$FILE_SUMMARY

If you haven't already, run /endor-review to perform a security check before creating a PR. This covers: dependency vulnerabilities, SAST findings, exposed secrets, and license compliance.
EOF

# Clean up state file
rm -f "$STATE_FILE" 2>/dev/null || true

exit 0
