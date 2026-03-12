#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: Track security-sensitive file modifications
# =============================================================================
# Records which security-sensitive files were modified during the session.
# The session-review-reminder.sh (Stop hook) reads this state to determine
# if a security review is needed before the session ends.
#
# Fires on: PostToolUse → Edit|Write
# Exit 0 + no output = always silent (tracking only, no context injection)
#
# State file: /tmp/claude-security-{SESSION_ID}
#
# Test: echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/login.js"},"session_id":"test123"}' | .claude/hooks/track-security-files.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[[ -z "$SESSION_ID" ]] && exit 0

FILENAME=$(basename "$FILE_PATH")

# Determine if this file is security-sensitive
IS_SENSITIVE=false

# Source code files that handle auth/security
case "$FILENAME" in
  *auth*|*login*|*session*|*token*|*password*|*credential*|*permission*|*access*|*security*|*crypto*|*encrypt*|*decrypt*)
    IS_SENSITIVE=true ;;
esac

# Container and infrastructure files
case "$FILENAME" in
  Dockerfile*|docker-compose*|*.tf|*.tfvars|*.yaml|*.yml)
    if echo "$FILE_PATH" | grep -qiP '(k8s|kubernetes|helm|deploy|infra|terraform|docker)'; then
      IS_SENSITIVE=true
    fi
    ;;
esac

# CI/CD config files
case "$FILE_PATH" in
  *.github/workflows/*|*.gitlab-ci*|*Jenkinsfile*|*azure-pipelines*|*bitbucket-pipelines*|*.circleci/*)
    IS_SENSITIVE=true ;;
esac

# Dependency manifests
case "$FILENAME" in
  package.json|requirements*.txt|pyproject.toml|Pipfile|Cargo.toml|go.mod|Gemfile|composer.json|pom.xml|build.gradle*)
    IS_SENSITIVE=true ;;
esac

# Dockerfile and compose at top level
case "$FILENAME" in
  Dockerfile*|docker-compose*|Containerfile*|compose.yml|compose.yaml)
    IS_SENSITIVE=true ;;
esac

[[ "$IS_SENSITIVE" != "true" ]] && exit 0

# Write to session state file (append, deduplicated on read)
STATE_FILE="/tmp/claude-security-${SESSION_ID}"
echo "$FILE_PATH" >> "$STATE_FILE" 2>/dev/null || true

# Silent — no output, just tracking
exit 0
