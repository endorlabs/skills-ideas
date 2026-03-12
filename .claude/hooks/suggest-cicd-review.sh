#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: CI/CD pipeline security review after config edits
# =============================================================================
# Complements: protect-files.sh (generic warning on CI/CD files)
# This hook adds: unpinned action/image detection + /endor-cicd suggestion.
#
# Fires on: PostToolUse → Edit|Write
# Exit 0 + stdout = inject warnings and skill suggestion
# Exit 0 + no output = not a CI/CD config file
#
# Test: echo '{"tool_name":"Write","tool_input":{"file_path":".github/workflows/ci.yml","content":"uses: actions/checkout@main"},"cwd":"/tmp"}' | .claude/hooks/suggest-cicd-review.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# Detect CI/CD config files
IS_CICD=false
case "$FILE_PATH" in
  *.github/workflows/*.yml|*.github/workflows/*.yaml) IS_CICD=true ;;
  *.gitlab-ci.yml|*.gitlab-ci.yaml) IS_CICD=true ;;
  *Jenkinsfile*) IS_CICD=true ;;
  *azure-pipelines.yml|*azure-pipelines.yaml) IS_CICD=true ;;
  *bitbucket-pipelines.yml|*bitbucket-pipelines.yaml) IS_CICD=true ;;
  *.circleci/config.yml|*.circleci/config.yaml) IS_CICD=true ;;
esac

# Also check filename patterns for cases where path doesn't include parent dirs
FILENAME=$(basename "$FILE_PATH")
case "$FILENAME" in
  .gitlab-ci.yml|.gitlab-ci.yaml) IS_CICD=true ;;
  Jenkinsfile|Jenkinsfile.*) IS_CICD=true ;;
  azure-pipelines.yml|azure-pipelines.yaml) IS_CICD=true ;;
  bitbucket-pipelines.yml|bitbucket-pipelines.yaml) IS_CICD=true ;;
esac

[[ "$IS_CICD" != "true" ]] && exit 0

# Read file content
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
FULL_PATH="$FILE_PATH"
[[ ! "$FILE_PATH" = /* ]] && FULL_PATH="$CWD/$FILE_PATH"

FILE_CONTENT=""
[[ -f "$FULL_PATH" ]] && FILE_CONTENT=$(cat "$FULL_PATH" 2>/dev/null || true)

WARNINGS=""

if [[ -n "$FILE_CONTENT" ]]; then
  # Unpinned GitHub Actions (using @main, @master, @v1 instead of SHA)
  if echo "$FILE_CONTENT" | grep -qP 'uses:\s+\S+@(main|master|v\d+)\s*$' 2>/dev/null; then
    WARNINGS="${WARNINGS}\n  - Unpinned GitHub Actions — pin to full SHA for supply chain security"
  fi

  # Unpinned Docker images (:latest or no tag)
  if echo "$FILE_CONTENT" | grep -qP 'image:\s+\S+:latest' 2>/dev/null; then
    WARNINGS="${WARNINGS}\n  - Docker image with :latest tag — pin to specific version"
  fi

  # Secrets in plain text (common CI/CD mistake)
  if echo "$FILE_CONTENT" | grep -qiP '(password|token|secret|api_key):\s*["\x27]?[A-Za-z0-9+/=]{8,}' 2>/dev/null; then
    if ! echo "$FILE_CONTENT" | grep -qP '\$\{\{.*secrets\.' 2>/dev/null; then
      WARNINGS="${WARNINGS}\n  - Possible hardcoded secret — use CI/CD secret variables (\${{ secrets.* }})"
    fi
  fi

  # Overly permissive permissions
  if echo "$FILE_CONTENT" | grep -qP 'permissions:\s*write-all' 2>/dev/null; then
    WARNINGS="${WARNINGS}\n  - write-all permissions — use least-privilege per-job permissions"
  fi

  # pull_request_target with checkout (dangerous pattern)
  if echo "$FILE_CONTENT" | grep -qP 'pull_request_target' 2>/dev/null; then
    if echo "$FILE_CONTENT" | grep -qP 'actions/checkout' 2>/dev/null; then
      WARNINGS="${WARNINGS}\n  - pull_request_target with checkout — potential code injection vector"
    fi
  fi
fi

MSG=""
if [[ -n "$WARNINGS" ]]; then
  MSG="[HOOK: CI/CD Security Issues]\nFile: $FILE_PATH\nIssues:${WARNINGS}\n\n"
fi

MSG="${MSG}[HOOK: CI/CD Config Modified] Review $FILE_PATH for security best practices. Run /endor-cicd to generate a secure baseline CI/CD configuration with Endor Labs scanning integrated."

echo -e "$MSG"
exit 0
