#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: Suggest license check alongside dependency install
# =============================================================================
# Complements: check-dep-install.sh (triggers /endor-check for vulns)
# This hook adds a parallel /endor-license suggestion because a dependency
# can be vulnerability-free but have an incompatible license (GPL, AGPL).
#
# Fires on: PostToolUse → Bash
# Exit 0 + stdout = inject license check reminder
# Exit 0 + no output = not a dependency install command
#
# Test: echo '{"tool_name":"Bash","tool_input":{"command":"npm install lodash"}}' | .claude/hooks/suggest-license-check.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ "$TOOL_NAME" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Same dependency install patterns as check-dep-install.sh
# We detect the same trigger but inject a DIFFERENT reminder (license, not vuln)
MATCHED=false
for pattern in \
  'npm install' 'npm i ' 'npm i$' 'npm add' \
  'yarn add' \
  'pnpm add' \
  'pip install' 'pip3 install' \
  'poetry add' \
  'cargo add' \
  'go get ' \
  'gem install' 'bundle add' \
  'dotnet add package' \
  'composer require'; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    MATCHED=true
    break
  fi
done

[[ "$MATCHED" != "true" ]] && exit 0

# Don't fire for bare installs (npm install, npm ci, yarn install, etc.)
# Those install from lockfile and license was checked when deps were added
BARE_PATTERNS='(^npm (install|ci|i)$|^yarn install$|^pnpm install$|^pip install -r|^bundle install$|^composer install$|^poetry install$)'
if echo "$COMMAND" | grep -qiE "$BARE_PATTERNS"; then
  exit 0
fi

cat <<EOF
[HOOK: License Compliance Reminder]
In addition to vulnerability checks (/endor-check), also verify license compatibility by running /endor-license. A dependency can be CVE-free but carry a copyleft license (GPL, AGPL) that may be incompatible with your project.
EOF

exit 0
