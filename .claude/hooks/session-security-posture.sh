#!/usr/bin/env bash
# =============================================================================
# SessionStart hook: Inject security posture summary at session start
# =============================================================================
# On session startup or context compaction, checks for recent scan results
# and injects a brief security posture summary. After compaction, re-injects
# critical security reminders that may have been lost.
#
# Fires on: SessionStart → startup|compact
# Exit 0 + stdout = inject security posture context
# Exit 0 + no output = no scan data found
#
# Test: echo '{"hook_event_name":"SessionStart","session_id":"test123","cwd":"/home/user/project"}' | .claude/hooks/session-security-posture.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
EVENT_SOURCE=$(echo "$INPUT" | jq -r '.source // empty')

# Check for Endor Labs scan cache
ENDOR_CACHE=""
for dir in "$CWD/.endor" "$CWD/.endorctl"; do
  if [[ -d "$dir" ]]; then
    ENDOR_CACHE="$dir"
    break
  fi
done

MSG=""

# If scan cache exists, report last scan time
if [[ -n "$ENDOR_CACHE" ]]; then
  # Find most recent scan result file
  LATEST_SCAN=$(find "$ENDOR_CACHE" -name "*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || true)

  if [[ -n "$LATEST_SCAN" ]]; then
    SCAN_DATE=$(date -r "$LATEST_SCAN" "+%Y-%m-%d %H:%M" 2>/dev/null || stat -c '%y' "$LATEST_SCAN" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
    MSG="[HOOK: Security Posture] Last local scan cache: $SCAN_DATE."
  fi
fi

# Check for security-sensitive file tracking from previous/current session
STATE_FILE="/tmp/claude-security-${SESSION_ID}"
if [[ -f "$STATE_FILE" ]]; then
  FILE_COUNT=$(wc -l < "$STATE_FILE" 2>/dev/null || echo "0")
  if [[ "$FILE_COUNT" -gt 0 ]]; then
    MSG="${MSG} ${FILE_COUNT} security-sensitive file(s) modified this session — run /endor-review before creating a PR."
  fi
fi

# On compaction, re-inject critical security context
if [[ "$EVENT_SOURCE" == "compact" ]]; then
  COMPACT_MSG="[HOOK: Context Compacted — Security Reminders]"
  COMPACT_MSG="${COMPACT_MSG} Available security commands: /endor-scan (quick scan), /endor-review (pre-PR gate), /endor-check (dep check), /endor-fix (remediation)."

  if [[ -f "$STATE_FILE" ]]; then
    COMPACT_MSG="${COMPACT_MSG} NOTE: Security-sensitive files were modified in this session."
  fi

  MSG="${MSG}\n${COMPACT_MSG}"
fi

# Check for common security files that might need attention
if [[ -f "$CWD/.env" ]] && ! [[ -f "$CWD/.gitignore" ]] 2>/dev/null; then
  MSG="${MSG}\n[HOOK: Warning] .env file exists but no .gitignore found — risk of committing secrets."
elif [[ -f "$CWD/.env" ]] && [[ -f "$CWD/.gitignore" ]]; then
  if ! grep -qP '\.env' "$CWD/.gitignore" 2>/dev/null; then
    MSG="${MSG}\n[HOOK: Warning] .env file exists but is not in .gitignore — risk of committing secrets."
  fi
fi

if [[ -n "$MSG" ]]; then
  echo -e "$MSG"
fi

exit 0
