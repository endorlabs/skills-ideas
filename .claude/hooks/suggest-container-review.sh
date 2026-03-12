#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: Container security review after Dockerfile/compose edits
# =============================================================================
# Complements: protect-files.sh (generic warning on container files)
# This hook adds: specific inline pattern warnings + /endor-container suggestion.
#
# Fires on: PostToolUse → Edit|Write
# Exit 0 + stdout = inject inline warnings and skill suggestion
# Exit 0 + no output = not a container file
#
# Test: echo '{"tool_name":"Write","tool_input":{"file_path":"Dockerfile","content":"FROM node:latest\nRUN npm install\nEXPOSE 22"},"cwd":"/tmp"}' | .claude/hooks/suggest-container-review.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

FILENAME=$(basename "$FILE_PATH")
FILENAME_LOWER=$(echo "$FILENAME" | tr '[:upper:]' '[:lower:]')

# Determine container file type
IS_DOCKERFILE=false
IS_COMPOSE=false

case "$FILENAME_LOWER" in
  dockerfile*|containerfile*) IS_DOCKERFILE=true ;;
  docker-compose*|compose.yml|compose.yaml) IS_COMPOSE=true ;;
  *) exit 0 ;;
esac

# Resolve full path for reading
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
FULL_PATH="$FILE_PATH"
[[ ! "$FILE_PATH" = /* ]] && FULL_PATH="$CWD/$FILE_PATH"

# Read file content (just written/edited)
FILE_CONTENT=""
[[ -f "$FULL_PATH" ]] && FILE_CONTENT=$(cat "$FULL_PATH" 2>/dev/null || true)
[[ -z "$FILE_CONTENT" ]] && exit 0

WARNINGS=""

if [[ "$IS_DOCKERFILE" == "true" ]]; then
  # :latest tag
  echo "$FILE_CONTENT" | grep -qiP 'FROM\s+\S+:latest(\s|$)' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - :latest tag on base image — pin to a specific version"

  # No USER directive (running as root)
  echo "$FILE_CONTENT" | grep -qiP '^\s*USER\s+' 2>/dev/null || \
    WARNINGS="${WARNINGS}\n  - No USER directive — container runs as root"

  # EXPOSE 22 (SSH)
  echo "$FILE_CONTENT" | grep -qP '^\s*EXPOSE\s+22(\s|$)' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - EXPOSE 22 — SSH should not run in containers"

  # Secrets in ARG/ENV
  echo "$FILE_CONTENT" | grep -qiP '^\s*(ARG|ENV)\s+(PASSWORD|SECRET|TOKEN|API_KEY|CREDENTIALS)\s*=' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - Secrets in ARG/ENV — visible in image layers, use runtime secrets"

  # No HEALTHCHECK
  echo "$FILE_CONTENT" | grep -qiP '^\s*HEALTHCHECK\s+' 2>/dev/null || \
    WARNINGS="${WARNINGS}\n  - No HEALTHCHECK — add one for orchestration liveness"

  # ADD instead of COPY (not for tar/URL extraction)
  echo "$FILE_CONTENT" | grep -qP '^\s*ADD\s+(?!https?://)(?!.*\.tar)' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - ADD used instead of COPY — prefer COPY unless extracting archives"
fi

if [[ "$IS_COMPOSE" == "true" ]]; then
  echo "$FILE_CONTENT" | grep -qP 'privileged:\s*true' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - privileged: true — full host access, remove unless required"

  echo "$FILE_CONTENT" | grep -qP 'network_mode:\s*["\x27]?host' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - network_mode: host — bypasses network isolation"

  echo "$FILE_CONTENT" | grep -qP '/var/run/docker\.sock' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - docker.sock mount — enables container escape"

  echo "$FILE_CONTENT" | grep -qP '0\.0\.0\.0:' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - Binding to 0.0.0.0 — use 127.0.0.1 for local-only access"

  # Missing resource limits (check for deploy.resources or mem_limit)
  if ! echo "$FILE_CONTENT" | grep -qP '(mem_limit|memory|resources)' 2>/dev/null; then
    WARNINGS="${WARNINGS}\n  - No resource limits — add deploy.resources.limits"
  fi
fi

MSG=""
if [[ -n "$WARNINGS" ]]; then
  MSG="[HOOK: Container Security Issues]\nFile: $FILE_PATH\nIssues:${WARNINGS}\n\n"
fi

MSG="${MSG}[HOOK: Container File Modified] Run /endor-container to perform a comprehensive container security analysis of $FILE_PATH."

echo -e "$MSG"
exit 0
