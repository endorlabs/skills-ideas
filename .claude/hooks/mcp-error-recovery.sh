#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: Error recovery for Endor Labs MCP tool failures
# =============================================================================
# Detects auth failures, scan errors, and other MCP tool issues.
# Routes to /endor-setup for auth problems and /endor-troubleshoot for
# scan failures.
#
# Fires on: PostToolUse → mcp__endor-cli-tools__.*
# Exit 0 + stdout = inject recovery suggestion
# Exit 0 + no output = tool succeeded, no action needed
#
# Test: echo '{"tool_name":"mcp__endor-cli-tools__scan","tool_output":"error: authentication failed","tool_error":"auth token expired"}' | .claude/hooks/mcp-error-recovery.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process Endor MCP tools
if ! echo "$TOOL_NAME" | grep -qP '^mcp__endor-cli-tools__'; then
  exit 0
fi

# Check for error indicators in various possible fields
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null || true)
TOOL_ERROR=$(echo "$INPUT" | jq -r '.tool_error // .error // empty' 2>/dev/null || true)
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null || true)

# Combine all possible error text
ERROR_TEXT="${TOOL_OUTPUT} ${TOOL_ERROR} ${TOOL_RESULT}"

# No error indicators — silent exit
if [[ -z "$(echo "$ERROR_TEXT" | tr -d ' ')" ]]; then
  exit 0
fi

# Detect auth-related errors
if echo "$ERROR_TEXT" | grep -qiP '(auth(entication|orization)?\s*(fail|error|expire|invalid|denied)|token\s*(expire|invalid|missing)|401|403|unauthenticated|unauthorized|login\s*required|credential|ENDOR_TOKEN)' 2>/dev/null; then
  cat <<EOF
[HOOK: Endor Labs Authentication Error]
The MCP tool ($TOOL_NAME) failed with an authentication error.
Run /endor-setup to reconfigure authentication, or check that:
- ENDOR_NAMESPACE is set correctly
- Your auth token hasn't expired (re-authenticate via browser)
- ENDOR_MCP_SERVER_AUTH_MODE matches your login method
EOF
  exit 0
fi

# Detect scan/build errors
if echo "$ERROR_TEXT" | grep -qiP '(scan\s*(fail|error)|build\s*(fail|error)|compilation\s*(fail|error)|toolchain|not\s*found.*command|missing\s*dependency|no\s*such\s*file|timeout|timed?\s*out)' 2>/dev/null; then
  cat <<EOF
[HOOK: Endor Labs Scan Error]
The MCP tool ($TOOL_NAME) encountered a scan or build error.
Run /endor-troubleshoot to diagnose the failure and get remediation steps.
Common causes: missing build toolchain, wrong language version, network timeout.
EOF
  exit 0
fi

# Detect namespace errors
if echo "$ERROR_TEXT" | grep -qiP '(namespace\s*(not\s*found|invalid|missing)|ENDOR_NAMESPACE|no\s*project|project\s*not\s*found)' 2>/dev/null; then
  cat <<EOF
[HOOK: Endor Labs Namespace Error]
The MCP tool ($TOOL_NAME) failed — namespace issue detected.
Check that ENDOR_NAMESPACE is set to your organization's namespace.
Run /endor-setup to reconfigure if needed.
EOF
  exit 0
fi

# Generic error (don't inject for every minor issue — only if it looks like a real failure)
if echo "$ERROR_TEXT" | grep -qiP '(error|fail|exception|panic|fatal)' 2>/dev/null; then
  cat <<EOF
[HOOK: Endor Labs Tool Error]
The MCP tool ($TOOL_NAME) may have encountered an error. If the results look incomplete:
- Run /endor-troubleshoot to diagnose scan issues
- Run /endor-setup to verify configuration
EOF
  exit 0
fi

exit 0
