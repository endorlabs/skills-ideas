#!/usr/bin/env bash
# PreToolUse hook: Protect sensitive files from being edited
# Blocks or warns when Claude attempts to edit security-sensitive files
# like .env files, lockfiles, CI configs, or secrets.
#
# Exit 0 = allow
# Exit 2 + stderr = BLOCK with reason

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

FILENAME=$(basename "$FILE_PATH")
DIRPATH=$(dirname "$FILE_PATH")

# === BLOCKED FILES (exit 2) ===
# These files should never be edited by Claude

# .env files with actual secrets (not .env.example)
if [[ "$FILENAME" == ".env" ]] || [[ "$FILENAME" == ".env.local" ]] || [[ "$FILENAME" == ".env.production" ]]; then
  echo "BLOCKED: Cannot edit $FILENAME — this file likely contains secrets. Edit .env.example instead and let the user manage actual environment files." >&2
  exit 2
fi

# Private keys and certificates
if [[ "$FILENAME" == *.pem ]] || [[ "$FILENAME" == *.key ]] || [[ "$FILENAME" == *id_rsa* ]] || [[ "$FILENAME" == *id_ed25519* ]]; then
  echo "BLOCKED: Cannot edit $FILENAME — this appears to be a private key or certificate file." >&2
  exit 2
fi

# Credential files
if [[ "$FILENAME" == "credentials" ]] || [[ "$FILENAME" == "credentials.json" ]] || [[ "$FILENAME" == ".netrc" ]] || [[ "$FILENAME" == ".npmrc" ]]; then
  echo "BLOCKED: Cannot edit $FILENAME — this file may contain credentials. Let the user manage this file directly." >&2
  exit 2
fi

# === WARNED FILES (exit 0 with message) ===
# These files are sensitive but editable — inject a warning

WARNING=""

# CI/CD configs
if [[ "$FILENAME" == ".github" ]] || [[ "$FILE_PATH" == *".github/workflows"* ]] || \
   [[ "$FILENAME" == ".gitlab-ci.yml" ]] || [[ "$FILENAME" == "Jenkinsfile" ]] || \
   [[ "$FILENAME" == "azure-pipelines.yml" ]] || [[ "$FILENAME" == ".circleci"* ]]; then
  WARNING="CI/CD configuration file — changes here affect build/deploy pipelines. Review carefully."
fi

# Docker files
if [[ "$FILENAME" == "Dockerfile"* ]] || [[ "$FILENAME" == "docker-compose"* ]] || [[ "$FILENAME" == ".dockerignore" ]]; then
  WARNING="Container configuration file — ensure no secrets are embedded and security best practices are followed."
fi

# Terraform / Infrastructure
if [[ "$FILENAME" == *.tf ]] || [[ "$FILENAME" == *.tfvars ]]; then
  WARNING="Infrastructure-as-code file — changes here affect cloud resources. Ensure no secrets are hardcoded."
fi

# Lockfiles (usually auto-generated, shouldn't be manually edited)
if [[ "$FILENAME" == "package-lock.json" ]] || [[ "$FILENAME" == "yarn.lock" ]] || \
   [[ "$FILENAME" == "pnpm-lock.yaml" ]] || [[ "$FILENAME" == "Cargo.lock" ]] || \
   [[ "$FILENAME" == "Pipfile.lock" ]] || [[ "$FILENAME" == "composer.lock" ]] || \
   [[ "$FILENAME" == "Gemfile.lock" ]]; then
  WARNING="Lockfile — these are auto-generated. Edit the manifest file instead and run the package manager to regenerate the lockfile."
fi

if [[ -n "$WARNING" ]]; then
  echo "[HOOK: Sensitive File Warning] Editing $FILENAME — $WARNING"
fi

exit 0
