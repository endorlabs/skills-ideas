#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: Route scan results to actionable skills
# =============================================================================
# After the Endor Labs scan MCP tool completes, inject suggestions to:
# - Run /endor-findings to review results
# - Run /endor-fix for the most critical finding
# Creates the natural workflow: scan → findings → fix
#
# Fires on: PostToolUse → mcp__endor-cli-tools__scan
# Exit 0 + stdout = inject routing suggestion
# Exit 0 + no output = scan tool not detected (shouldn't happen with matcher)
#
# Test: echo '{"tool_name":"mcp__endor-cli-tools__scan","tool_input":{"path":"/repo","scan_types":["vulnerabilities"]},"tool_output":{"findings_count":5}}' | .claude/hooks/post-scan-routing.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Verify this is the scan tool (matcher should handle this, but be safe)
if [[ "$TOOL_NAME" != "mcp__endor-cli-tools__scan" ]]; then
  exit 0
fi

# Try to extract scan result info if available in tool_output
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null)

# Check if scan had findings (try multiple possible output formats)
HAS_FINDINGS=false
if [[ -n "$TOOL_OUTPUT" ]]; then
  # Check for various indicators of findings in the output
  FINDINGS_COUNT=$(echo "$TOOL_OUTPUT" | jq -r '.findings_count // .total_findings // .count // empty' 2>/dev/null || true)
  if [[ -n "$FINDINGS_COUNT" ]] && [[ "$FINDINGS_COUNT" != "0" ]]; then
    HAS_FINDINGS=true
  fi
fi

# Extract scan types for context
SCAN_TYPES=$(echo "$INPUT" | jq -r '.tool_input.scan_types // [] | join(", ")' 2>/dev/null || echo "unknown")

if [[ "$HAS_FINDINGS" == "true" ]]; then
  cat <<EOF
[HOOK: Scan Complete — Findings Detected]
The scan found security issues. Next steps:
1. Run /endor-findings to review all findings with filtering by severity and reachability
2. Run /endor-fix {CVE-ID} to get remediation guidance for the most critical finding
3. Run /endor-explain {CVE-ID} for detailed vulnerability information

Scan types: $SCAN_TYPES
EOF
else
  cat <<EOF
[HOOK: Scan Complete]
Scan finished (types: $SCAN_TYPES). Run /endor-findings to review detailed results, or /endor-fix {CVE-ID} if specific vulnerabilities were reported.
If zero critical issues were found — no action needed.
EOF
fi

exit 0
