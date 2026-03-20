#!/usr/bin/env bash
# PostToolUse hook: Detect dependency install commands from Bash tool
# When a dependency install is detected, injects a reminder into Claude's
# context to run /endor-check on the installed packages.
#
# Exit 0 + stdout message = inject message into Claude's context
# Exit 0 + no output = silent pass-through (not a dep install)

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Patterns that indicate dependency installation
# Each pattern captures the package manager command
DEP_PATTERNS=(
  'npm install'
  'npm i '
  'npm i$'
  'npm ci'
  'npm add'
  'yarn add'
  'yarn install'
  'pnpm add'
  'pnpm install'
  'pip install'
  'pip3 install'
  'poetry add'
  'poetry install'
  'cargo add'
  'cargo install'
  'go get '
  'go mod tidy'
  'gem install'
  'bundle install'
  'bundle add'
  'dotnet add package'
  'composer require'
  'composer install'
  'composer update'
)

MATCHED=""
for pattern in "${DEP_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    MATCHED="$pattern"
    break
  fi
done

if [[ -z "$MATCHED" ]]; then
  exit 0
fi

# Extract package names from common install commands
PACKAGES=""

# npm/yarn/pnpm: extract packages after install/add command
if echo "$COMMAND" | grep -qiE '(npm install|npm i |npm add|yarn add|pnpm add)'; then
  # Strip flags (--save-dev, -D, etc.) and extract package names
  PACKAGES=$(echo "$COMMAND" | sed -E 's/.*(npm install|npm i|npm add|yarn add|pnpm add)//' | sed -E 's/--?[a-zA-Z-]+//g' | xargs)
fi

# pip: extract packages after install
if echo "$COMMAND" | grep -qiE '(pip3? install)'; then
  PACKAGES=$(echo "$COMMAND" | sed -E 's/.*(pip3? install)//' | sed -E 's/--?[a-zA-Z-]+ ?[^ ]*//g' | sed 's/-r [^ ]*//' | xargs)
fi

# go get: extract module path
if echo "$COMMAND" | grep -qiE 'go get '; then
  PACKAGES=$(echo "$COMMAND" | sed -E 's/.*go get //' | sed -E 's/--?[a-zA-Z-]+//g' | xargs)
fi

# cargo add: extract crate names
if echo "$COMMAND" | grep -qiE 'cargo add'; then
  PACKAGES=$(echo "$COMMAND" | sed -E 's/.*cargo add//' | sed -E 's/--?[a-zA-Z-]+ ?[^ ]*//g' | xargs)
fi

# gem install / bundle add
if echo "$COMMAND" | grep -qiE '(gem install|bundle add)'; then
  PACKAGES=$(echo "$COMMAND" | sed -E 's/.*(gem install|bundle add)//' | sed -E 's/--?[a-zA-Z-]+ ?[^ ]*//g' | xargs)
fi

# Build the reminder message
if [[ -n "$PACKAGES" ]]; then
  cat <<EOF
[HOOK: Dependency Install Detected]
Command: $COMMAND
Packages: $PACKAGES

You MUST now run /endor-check for each package listed above to check for known vulnerabilities before proceeding. This is a mandatory security check.
EOF
else
  cat <<EOF
[HOOK: Dependency Install Detected]
Command: $COMMAND

A dependency install command was detected but specific packages could not be parsed. Read the relevant manifest file in the working directory to identify the dependencies, then run /endor-check on each one.
EOF
fi

exit 0
