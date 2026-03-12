#!/usr/bin/env bash
# PreToolUse hook: Block git commits/pushes if staged files contain secrets
# Scans staged files for common secret patterns (API keys, tokens, passwords)
# before allowing git commit or git push to proceed.
#
# Exit 0 = allow the command
# Exit 2 + stderr = BLOCK the command with reason

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Only check git commit and git push commands
if ! echo "$COMMAND" | grep -qE '^\s*(git\s+commit|git\s+push)'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
if [[ -z "$CWD" ]]; then
  CWD="."
fi

# For git push, we check the diff against the remote branch
# For git commit, we check staged files
FINDINGS=""

if echo "$COMMAND" | grep -qE '^\s*git\s+commit'; then
  # Get staged file contents
  STAGED_DIFF=$(cd "$CWD" 2>/dev/null && git diff --cached --unified=0 2>/dev/null || true)
else
  # For push, check unpushed commits
  STAGED_DIFF=$(cd "$CWD" 2>/dev/null && git diff @{upstream}..HEAD 2>/dev/null || true)
fi

if [[ -z "$STAGED_DIFF" ]]; then
  exit 0
fi

# Secret patterns to scan for
# Each pattern is: "LABEL:::REGEX"
SECRET_PATTERNS=(
  "AWS Access Key:::AKIA[0-9A-Z]{16}"
  "AWS Secret Key:::[0-9a-zA-Z/+]{40}"
  "GitHub Token:::gh[ps]_[A-Za-z0-9_]{36,}"
  "GitHub OAuth:::gho_[A-Za-z0-9_]{36,}"
  "GitLab Token:::glpat-[A-Za-z0-9\-_]{20,}"
  "Slack Token:::xox[baprs]-[0-9A-Za-z\-]{10,}"
  "Stripe Secret Key:::sk_live_[0-9a-zA-Z]{24,}"
  "Stripe Publishable:::pk_live_[0-9a-zA-Z]{24,}"
  "Google API Key:::AIza[0-9A-Za-z\-_]{35}"
  "NPM Token:::npm_[A-Za-z0-9]{36,}"
  "PyPI Token:::pypi-[A-Za-z0-9\-_]{16,}"
  "Private Key:::-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
  "Generic Secret:::(?i)(password|passwd|pwd|secret|token|api_key|apikey|api-key|access_key|auth_token)\s*[=:]\s*['\"][^\s'\"]{8,}['\"]"
  "Connection String:::(?i)(mongodb|postgres|mysql|redis|amqp)://[^\s'\"]+:[^\s'\"]+@"
  "Basic Auth URL:::https?://[^\s:]+:[^\s@]+@"
)

for entry in "${SECRET_PATTERNS[@]}"; do
  LABEL="${entry%%:::*}"
  PATTERN="${entry##*:::}"

  # Only check added lines (lines starting with +, excluding +++ header)
  MATCHES=$(echo "$STAGED_DIFF" | grep -E '^\+[^+]' | grep -oP "$PATTERN" 2>/dev/null | head -5 || true)

  if [[ -n "$MATCHES" ]]; then
    FINDINGS="${FINDINGS}\n  - ${LABEL}: $(echo "$MATCHES" | head -1 | cut -c1-40)..."
  fi
done

if [[ -n "$FINDINGS" ]]; then
  cat >&2 <<EOF
BLOCKED: Potential secrets detected in staged changes.

Findings:${FINDINGS}

Remove these secrets before committing. Use environment variables or a secrets manager instead.

To scan in detail, run /endor-secrets.
EOF
  exit 2
fi

exit 0
