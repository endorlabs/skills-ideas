#!/usr/bin/env bash
# =============================================================================
# PreToolUse hook: Warn when writing content containing potential secrets
# =============================================================================
# Complements: pre-commit-secrets.sh (catches at commit time)
# This hook catches secrets BEFORE they reach the filesystem.
#
# Fires on: PreToolUse → Edit|Write
# Exit 0 + stdout = warn (allow but inject warning)
# Exit 0 + no output = silent allow (no secrets detected)
#
# NOTE: This hook WARNS, not BLOCKS. The pattern could be a false positive
# in test files, documentation, or example configs.
#
# Test: echo '{"tool_name":"Edit","tool_input":{"file_path":"config.js","new_string":"const key = \"AKIAIOSFODNN7EXAMPLE\";"}}' | .claude/hooks/warn-secrets-at-write.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

# Extract the content being written
if [[ "$TOOL_NAME" == "Edit" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
else
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
fi

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
FILENAME=$(basename "$FILE_PATH" 2>/dev/null || echo "")

# Skip files that commonly contain example/fake secrets
case "$FILENAME" in
  *.example|*.sample|*.template|*.md|*.rst|*.txt|SKILL.md|PROMPT.md|README*)
    exit 0 ;;
esac

# Skip test files (common patterns across languages)
if echo "$FILENAME" | grep -qiP '(test|spec|mock|fixture|fake|stub|snapshot)'; then
  exit 0
fi

# Fast check: scan for high-confidence secret patterns
# These are chosen for low false-positive rates
FINDINGS=""

echo "$CONTENT" | grep -qP 'AKIA[0-9A-Z]{16}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - AWS Access Key (AKIA...)"

echo "$CONTENT" | grep -qP 'gh[ps]_[A-Za-z0-9_]{36,}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - GitHub Token (ghp_/ghs_...)"

echo "$CONTENT" | grep -qP 'glpat-[A-Za-z0-9\-_]{20,}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - GitLab Token (glpat-...)"

echo "$CONTENT" | grep -qP 'xox[baprs]-[0-9A-Za-z\-]{10,}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - Slack Token (xox*-...)"

echo "$CONTENT" | grep -qP 'sk_live_[0-9a-zA-Z]{24,}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - Stripe Secret Key (sk_live_...)"

echo "$CONTENT" | grep -qP 'pk_live_[0-9a-zA-Z]{24,}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - Stripe Publishable Key (pk_live_...)"

echo "$CONTENT" | grep -qP 'AIza[0-9A-Za-z\-_]{35}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - Google API Key (AIza...)"

echo "$CONTENT" | grep -qP 'npm_[A-Za-z0-9]{36,}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - NPM Token (npm_...)"

echo "$CONTENT" | grep -qP 'pypi-[A-Za-z0-9\-_]{16,}' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - PyPI Token (pypi-...)"

echo "$CONTENT" | grep -qP '\-\-\-\-\-BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY\-\-\-\-\-' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - Private Key (-----BEGIN...PRIVATE KEY-----)"

echo "$CONTENT" | grep -qiP '(password|passwd|secret|api_key|apikey|auth_token|access_token)\s*[=:]\s*['"'"'"][^\s'"'"'"]{8,}['"'"'"]' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - Hardcoded credential assignment"

echo "$CONTENT" | grep -qiP '(mongodb|postgres|mysql|redis|amqp)://[^\s:]+:[^\s@]+@' 2>/dev/null && \
  FINDINGS="${FINDINGS}\n  - Connection string with embedded credentials"

if [[ -n "$FINDINGS" ]]; then
  cat <<EOF
[HOOK: Potential Secret in Content Being Written]
File: $FILE_PATH
Patterns found:${FINDINGS}

The content being written may contain hardcoded secrets. Use environment variables or a secrets manager instead.
If these are intentional test/example values, proceed. Otherwise, replace secrets with references like process.env.API_KEY or os.environ.get("API_KEY").
Run /endor-secrets for a comprehensive secrets scan.
EOF
fi

exit 0
