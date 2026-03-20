#!/usr/bin/env bash
# UserPromptSubmit hook: Detect when user intends to create a PR or push code
# Injects a reminder to run /endor-review before proceeding.
#
# Exit 0 + stdout = inject reminder into context
# Exit 0 + no output = no PR intent detected, pass through silently

set -euo pipefail

INPUT=$(cat)

PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

if [[ -z "$PROMPT" ]]; then
  exit 0
fi

# Convert to lowercase for matching
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Patterns that indicate PR/merge/push intent
# Be specific to avoid false positives on casual mentions
PR_PATTERNS=(
  "create a pr"
  "create a pull request"
  "create pr"
  "create pull request"
  "open a pr"
  "open a pull request"
  "open pr"
  "open pull request"
  "make a pr"
  "make a pull request"
  "submit a pr"
  "submit a pull request"
  "push to main"
  "push to master"
  "push to production"
  "push to prod"
  "merge to main"
  "merge to master"
  "merge this"
  "ready to merge"
  "ready for review"
  "ready for merge"
  "let's merge"
  "ship it"
  "deploy this"
)

MATCHED=false
for pattern in "${PR_PATTERNS[@]}"; do
  if echo "$PROMPT_LOWER" | grep -qF "$pattern"; then
    MATCHED=true
    break
  fi
done

if [[ "$MATCHED" != "true" ]]; then
  exit 0
fi

# Check if user is already asking for endor-review
if echo "$PROMPT_LOWER" | grep -qF "endor-review"; then
  exit 0
fi
if echo "$PROMPT_LOWER" | grep -qF "endor review"; then
  exit 0
fi

cat <<EOF
[HOOK: PR/Merge Intent Detected]
Before creating a PR or pushing code, run /endor-review to perform a pre-PR security review. This checks for:
- Vulnerable dependencies
- SAST findings (SQL injection, XSS, etc.)
- Exposed secrets
- License compliance issues

If the user explicitly asked to skip the review, acknowledge the reminder and proceed.
EOF

exit 0
