#!/usr/bin/env bash
# =============================================================================
# UserPromptSubmit hook: Suggest relevant Endor Labs skills based on prompt
# =============================================================================
# Detects when the user mentions CVE IDs, asks about package safety, mentions
# GitHub Actions workflow security, or mentions "demo/try" in the context of
# security tools — and suggests the appropriate skill.
#
# Complements: detect-pr-intent.sh (which handles PR/merge intent)
# This hook handles: CVE references, package evaluation, demo requests.
#
# Fires on: UserPromptSubmit
# Exit 0 + stdout = inject skill suggestion
# Exit 0 + no output = no relevant patterns in prompt
#
# Test: echo '{"prompt":"What is CVE-2024-38816 and how bad is it?"}' | .claude/hooks/suggest-endor-tools.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
[[ -z "$PROMPT" ]] && exit 0

PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Skip if user is already invoking an endor skill
if echo "$PROMPT_LOWER" | grep -qP '(/endor|endor-check|endor-explain|endor-score|endor-demo|endor-fix|endor-scan|endor-review|endor-sast|endor-ai-sast|endor-secrets|endor-license|endor-container|endor-cicd|endor-ghactions|endor-supply-chain)'; then
  exit 0
fi

SUGGESTIONS=""

# --- CVE/GHSA mention → /endor-explain ---
CVE_ID=$(echo "$PROMPT" | grep -oP 'CVE-\d{4}-\d{4,}' | head -1 || true)
GHSA_ID=$(echo "$PROMPT" | grep -oP 'GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}' | head -1 || true)

if [[ -n "$CVE_ID" ]]; then
  SUGGESTIONS="${SUGGESTIONS}\n- Run /endor-explain $CVE_ID for detailed vulnerability information (severity, impact, remediation)"
fi
if [[ -n "$GHSA_ID" ]]; then
  SUGGESTIONS="${SUGGESTIONS}\n- Run /endor-explain $GHSA_ID for detailed vulnerability information"
fi

# --- Package safety/evaluation → /endor-score ---
if echo "$PROMPT_LOWER" | grep -qP '(is\s+(this|that|it)\s+(package|library|dependency)\s+safe|should (i|we) use|how (safe|secure|reliable) is|evaluate\s+(this\s+)?package|package\s+(health|quality|reputation|score))'; then
  SUGGESTIONS="${SUGGESTIONS}\n- Run /endor-score to evaluate the package's health, security, and quality metrics"
fi

# --- Demo/trial request → /endor-demo ---
if echo "$PROMPT_LOWER" | grep -qP '(demo\s+endor|try\s+endor|endor\s+demo|endor\s+trial|test\s+endor|show\s+me\s+(how\s+)?endor|without\s+(an\s+)?account)'; then
  SUGGESTIONS="${SUGGESTIONS}\n- Run /endor-demo to try Endor Labs capabilities with simulated data (no account needed)"
fi

# --- Troubleshooting → /endor-troubleshoot ---
if echo "$PROMPT_LOWER" | grep -qP '(scan\s+(fail|error|broke|not\s+work)|endor.*(fail|error|broken|not\s+work)|(fail|error|broken).*endor|endorctl.*(error|fail))'; then
  SUGGESTIONS="${SUGGESTIONS}\n- Run /endor-troubleshoot to diagnose scan failures and get remediation steps"
fi

# --- GitHub Actions workflow security → /endor-ghactions ---
if echo "$PROMPT_LOWER" | grep -qP '(github\s+actions?\s+(workflow|workflows|security|yaml|yml)|\.github/workflows|workflow\.ya?ml|insecure\s+(ci|workflow)|scan\s+(my\s+)?(gha|github\s+actions)|vulnerable\s+action(s)?(\s+version)?|harden\s+(my\s+)?(gha|github\s+actions))'; then
  SUGGESTIONS="${SUGGESTIONS}\n- Run /endor-ghactions to scan workflows for insecure patterns and vulnerable action versions"
fi

# --- Setup/configure → /endor-setup ---
if echo "$PROMPT_LOWER" | grep -qP '(set\s*up\s+endor|configure\s+endor|install\s+endor|endor\s+(setup|config|auth|install)|how\s+to\s+(start|begin|use)\s+endor)'; then
  SUGGESTIONS="${SUGGESTIONS}\n- Run /endor-setup for guided onboarding (prerequisites, auth, namespace, first scan)"
fi

if [[ -n "$SUGGESTIONS" ]]; then
  cat <<EOF
[HOOK: Endor Labs Tool Suggestions]
Based on your message, these tools may help:${SUGGESTIONS}
EOF
fi

exit 0
