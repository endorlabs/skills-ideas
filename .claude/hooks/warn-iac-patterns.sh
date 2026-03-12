#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: Warn on dangerous Infrastructure-as-Code patterns
# =============================================================================
# Detects security anti-patterns in Terraform, CloudFormation, and Kubernetes
# manifests after they are written. No /endor-iac skill exists yet, so this
# hook provides inline warnings and suggests manual review.
#
# Fires on: PostToolUse → Edit|Write
# Exit 0 + stdout = inject IaC security warnings
# Exit 0 + no output = not an IaC file or no issues found
#
# Test: echo '{"tool_name":"Write","tool_input":{"file_path":"main.tf","content":"resource \"aws_s3_bucket\" \"data\" {\n  acl = \"public-read\"\n}"},"cwd":"/tmp"}' | .claude/hooks/warn-iac-patterns.sh
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

# Detect IaC file types
IAC_TYPE=""
case "$FILENAME" in
  *.tf) IAC_TYPE="terraform" ;;
  *.tfvars) IAC_TYPE="terraform" ;;
  *template.yaml|*template.json|*cloudformation*) IAC_TYPE="cloudformation" ;;
  *.yaml|*.yml)
    # Check if it's a Kubernetes manifest (in k8s/kubernetes/helm dirs or has apiVersion)
    if echo "$FILE_PATH" | grep -qiP '(k8s|kubernetes|helm|manifests|deploy)'; then
      IAC_TYPE="kubernetes"
    fi
    ;;
esac

[[ -z "$IAC_TYPE" ]] && exit 0

# Read file content
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
FULL_PATH="$FILE_PATH"
[[ ! "$FILE_PATH" = /* ]] && FULL_PATH="$CWD/$FILE_PATH"

FILE_CONTENT=""
[[ -f "$FULL_PATH" ]] && FILE_CONTENT=$(cat "$FULL_PATH" 2>/dev/null || true)
[[ -z "$FILE_CONTENT" ]] && exit 0

# For YAML files not in k8s directories, check for apiVersion to confirm k8s
if [[ "$IAC_TYPE" == "" ]] && echo "$FILE_CONTENT" | grep -qP '^apiVersion:' 2>/dev/null; then
  IAC_TYPE="kubernetes"
fi

[[ -z "$IAC_TYPE" ]] && exit 0

WARNINGS=""

# --- Terraform ---
if [[ "$IAC_TYPE" == "terraform" ]]; then
  # Public S3 buckets
  echo "$FILE_CONTENT" | grep -qP 'acl\s*=\s*"public' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - Public ACL on S3 bucket — use private ACL and bucket policies"

  # Overly permissive IAM
  echo "$FILE_CONTENT" | grep -qP '"Action"\s*:\s*"\*"' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - IAM Action: \"*\" — use least-privilege permissions"
  echo "$FILE_CONTENT" | grep -qP '"Resource"\s*:\s*"\*"' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - IAM Resource: \"*\" — scope to specific resources"

  # Unencrypted resources
  echo "$FILE_CONTENT" | grep -qP 'encrypted\s*=\s*false' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - encrypted = false — enable encryption at rest"

  # Security group open to world
  echo "$FILE_CONTENT" | grep -qP 'cidr_blocks\s*=\s*\["0\.0\.0\.0/0"\]' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - CIDR 0.0.0.0/0 — restrict to specific IP ranges"

  # Hardcoded secrets in tfvars
  if [[ "$FILENAME" == *.tfvars ]]; then
    echo "$FILE_CONTENT" | grep -qiP '(password|secret|token|key)\s*=\s*"[^"]{8,}"' 2>/dev/null && \
      WARNINGS="${WARNINGS}\n  - Possible secret in .tfvars — use terraform.tfvars.example + env vars"
  fi
fi

# --- Kubernetes ---
if [[ "$IAC_TYPE" == "kubernetes" ]]; then
  # Privileged containers
  echo "$FILE_CONTENT" | grep -qP 'privileged:\s*true' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - privileged: true — grants full host access"

  # Running as root
  echo "$FILE_CONTENT" | grep -qP 'runAsUser:\s*0' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - runAsUser: 0 — container runs as root"

  # No resource limits
  if ! echo "$FILE_CONTENT" | grep -qP 'limits:' 2>/dev/null; then
    if echo "$FILE_CONTENT" | grep -qP 'containers:' 2>/dev/null; then
      WARNINGS="${WARNINGS}\n  - No resource limits — add CPU/memory limits"
    fi
  fi

  # hostNetwork
  echo "$FILE_CONTENT" | grep -qP 'hostNetwork:\s*true' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - hostNetwork: true — bypasses pod network isolation"

  # hostPID
  echo "$FILE_CONTENT" | grep -qP 'hostPID:\s*true' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - hostPID: true — allows access to host processes"

  # :latest image tag
  echo "$FILE_CONTENT" | grep -qP 'image:\s+\S+:latest' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - :latest image tag — pin to specific version"
fi

# --- CloudFormation ---
if [[ "$IAC_TYPE" == "cloudformation" ]]; then
  echo "$FILE_CONTENT" | grep -qP 'PubliclyAccessible:\s*(true|True)' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - PubliclyAccessible: true — review if this needs public access"

  echo "$FILE_CONTENT" | grep -qP '"Action":\s*\[?\s*"\*"' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - IAM Action: \"*\" — use least-privilege permissions"
fi

if [[ -n "$WARNINGS" ]]; then
  cat <<EOF
[HOOK: Infrastructure-as-Code Security Issues]
File: $FILE_PATH (${IAC_TYPE})
Issues:${WARNINGS}

Review these patterns for security best practices. No automated IaC scanning skill is available yet — perform manual review or use a dedicated IaC scanner (tfsec, checkov, kube-score).
EOF
fi

exit 0
