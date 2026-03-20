#!/usr/bin/env bash
# PostToolUse hook: Detect when dependency manifest files are edited
# Triggers when Edit or Write tools modify package.json, requirements.txt,
# pyproject.toml, go.mod, Cargo.toml, Gemfile, composer.json, pom.xml, etc.
#
# Exit 0 + stdout message = inject reminder into Claude's context
# Exit 0 + no output = silent pass-through (not a manifest file)

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process Edit and Write tool calls
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Get just the filename
FILENAME=$(basename "$FILE_PATH")

# Manifest files that indicate dependency changes
MANIFEST_FILES=(
  "package.json"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "requirements.txt"
  "requirements-dev.txt"
  "pyproject.toml"
  "Pipfile"
  "Pipfile.lock"
  "setup.py"
  "setup.cfg"
  "Cargo.toml"
  "Cargo.lock"
  "go.mod"
  "go.sum"
  "Gemfile"
  "Gemfile.lock"
  "composer.json"
  "composer.lock"
  "pom.xml"
  "build.gradle"
  "build.gradle.kts"
  "settings.gradle"
  "settings.gradle.kts"
)

IS_MANIFEST=false
for manifest in "${MANIFEST_FILES[@]}"; do
  if [[ "$FILENAME" == "$manifest" ]]; then
    IS_MANIFEST=true
    break
  fi
done

# Also match *.csproj, *.fsproj, *.vbproj files
if [[ "$FILENAME" == *.csproj ]] || [[ "$FILENAME" == *.fsproj ]] || [[ "$FILENAME" == *.vbproj ]]; then
  IS_MANIFEST=true
fi

if [[ "$IS_MANIFEST" != "true" ]]; then
  exit 0
fi

# Determine ecosystem from filename
ECOSYSTEM="unknown"
case "$FILENAME" in
  package.json|package-lock.json|yarn.lock|pnpm-lock.yaml)
    ECOSYSTEM="npm"
    ;;
  requirements*.txt|pyproject.toml|Pipfile*|setup.py|setup.cfg)
    ECOSYSTEM="python"
    ;;
  Cargo.toml|Cargo.lock)
    ECOSYSTEM="rust"
    ;;
  go.mod|go.sum)
    ECOSYSTEM="go"
    ;;
  Gemfile*)
    ECOSYSTEM="ruby"
    ;;
  composer.json|composer.lock)
    ECOSYSTEM="php"
    ;;
  pom.xml|build.gradle*|settings.gradle*)
    ECOSYSTEM="java"
    ;;
  *.csproj|*.fsproj|*.vbproj)
    ECOSYSTEM="dotnet"
    ;;
esac

cat <<EOF
[HOOK: Dependency Manifest Modified]
File: $FILE_PATH
Ecosystem: $ECOSYSTEM

A dependency manifest file was modified. Compare the changes to identify any new or updated dependencies, then run /endor-check on each new or updated dependency to check for known vulnerabilities. This is a mandatory security check.
EOF

exit 0
