#!/usr/bin/env bash
# =============================================================================
# PreToolUse hook: Warn when writing code with dangerous patterns
# =============================================================================
# Detects OWASP-top-10 patterns: eval/exec, innerHTML, SQL string concat,
# shell injection, unsafe deserialization BEFORE code is written.
# This is a fast regex check, NOT a full SAST scan. Suggests /endor-sast
# for thorough analysis.
#
# Fires on: PreToolUse → Edit|Write
# Exit 0 + stdout = warn with safe alternatives
# Exit 0 + no output = no dangerous patterns found
#
# Test: echo '{"tool_name":"Edit","tool_input":{"file_path":"app.py","new_string":"os.system(user_input)"}}' | .claude/hooks/warn-insecure-code.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# Only check source code files — exit immediately for everything else
FILENAME=$(basename "$FILE_PATH")
EXT="${FILENAME##*.}"
case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs) LANG="js" ;;
  py|pyw) LANG="py" ;;
  go) LANG="go" ;;
  java|kt|scala) LANG="java" ;;
  rb) LANG="rb" ;;
  php) LANG="php" ;;
  rs) LANG="rs" ;;
  cs) LANG="cs" ;;
  c|cpp|cc|h|hpp) LANG="c" ;;
  *) exit 0 ;;
esac

# Skip hook/rule/skill files to avoid false positives on pattern documentation
if echo "$FILE_PATH" | grep -qP '\.(claude|endor)/(hooks|rules|skills|ideas)/'; then
  exit 0
fi

# Extract content
if [[ "$TOOL_NAME" == "Edit" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
else
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
fi
[[ -z "$CONTENT" ]] && exit 0

WARNINGS=""

# --- JavaScript/TypeScript ---
if [[ "$LANG" == "js" ]]; then
  echo "$CONTENT" | grep -qP '\beval\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - eval() — use JSON.parse() or a safe parser"
  echo "$CONTENT" | grep -qP '\.innerHTML\s*=' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - innerHTML = — use textContent or DOMPurify.sanitize()"
  echo "$CONTENT" | grep -qP 'dangerouslySetInnerHTML' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - dangerouslySetInnerHTML — ensure input is sanitized"
  echo "$CONTENT" | grep -qP '\bnew\s+Function\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - new Function() — equivalent to eval(), avoid"
fi

# --- Python ---
if [[ "$LANG" == "py" ]]; then
  echo "$CONTENT" | grep -qP '\beval\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - eval() — use ast.literal_eval() or json.loads()"
  echo "$CONTENT" | grep -qP '\bexec\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - exec() — avoid dynamic code execution"
  echo "$CONTENT" | grep -qP 'os\.system\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - os.system() — use subprocess.run(shell=False, args=[...])"
  echo "$CONTENT" | grep -qP 'subprocess.*shell\s*=\s*True' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - subprocess(shell=True) — use shell=False with arg list"
  echo "$CONTENT" | grep -qP 'pickle\.loads?\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - pickle.load() — unsafe deserialization, use json.loads()"
  echo "$CONTENT" | grep -qP '\b__import__\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - __import__() — use importlib for dynamic imports"
  echo "$CONTENT" | grep -qP 'yaml\.load\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - yaml.load() — use yaml.safe_load() instead"
fi

# --- Go ---
if [[ "$LANG" == "go" ]]; then
  echo "$CONTENT" | grep -qP '"text/template"' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - text/template — use html/template for HTML output"
  echo "$CONTENT" | grep -qP '"math/rand"' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - math/rand — use crypto/rand for security-sensitive randomness"
fi

# --- Java/Kotlin/Scala ---
if [[ "$LANG" == "java" ]]; then
  echo "$CONTENT" | grep -qP 'Runtime\.getRuntime\(\)\.exec' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - Runtime.getRuntime().exec — use ProcessBuilder with validated args"
  echo "$CONTENT" | grep -qP 'ObjectInputStream' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - ObjectInputStream — unsafe deserialization, use JSON with type validation"
  echo "$CONTENT" | grep -qP 'ScriptEngine.*eval' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - ScriptEngine.eval() — avoid dynamic code execution"
fi

# --- Ruby ---
if [[ "$LANG" == "rb" ]]; then
  echo "$CONTENT" | grep -qP 'Marshal\.load' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - Marshal.load — unsafe deserialization, use JSON.parse()"
fi

# --- PHP ---
if [[ "$LANG" == "php" ]]; then
  echo "$CONTENT" | grep -qP '\beval\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - eval() — avoid dynamic code execution"
  echo "$CONTENT" | grep -qP '\bunserialize\s*\(' 2>/dev/null && \
    WARNINGS="${WARNINGS}\n  - unserialize() — unsafe deserialization, use json_decode()"
fi

# --- Cross-language: SQL injection patterns ---
echo "$CONTENT" | grep -qP "f[\"'](SELECT|INSERT|UPDATE|DELETE|DROP)\b.*\{" 2>/dev/null && \
  WARNINGS="${WARNINGS}\n  - SQL in f-string — use parameterized queries"
echo "$CONTENT" | grep -qP '`(SELECT|INSERT|UPDATE|DELETE|DROP)\b.*\$\{' 2>/dev/null && \
  WARNINGS="${WARNINGS}\n  - SQL in template literal — use parameterized queries"
echo "$CONTENT" | grep -qiP '(SELECT|INSERT|UPDATE|DELETE)\s+.*["'"'"']\s*\+\s*\w' 2>/dev/null && \
  WARNINGS="${WARNINGS}\n  - SQL string concatenation — use parameterized queries"

if [[ -n "$WARNINGS" ]]; then
  cat <<EOF
[HOOK: Insecure Code Pattern Detected]
File: $FILE_PATH ($LANG)
Patterns found:${WARNINGS}

These patterns are common sources of security vulnerabilities (injection, XSS, RCE, deserialization).
Use the safe alternatives listed above. Run /endor-sast for comprehensive static analysis.
EOF
fi

exit 0
