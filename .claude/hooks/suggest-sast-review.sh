#!/usr/bin/env bash
# =============================================================================
# PostToolUse hook: Suggest /endor-sast when writing security-sensitive code
# =============================================================================
# Detects when code handles user input, authentication, SQL, file I/O,
# or creates API endpoints — moments where SAST findings are most likely.
# Suggests running /endor-sast for comprehensive analysis.
#
# This is NOT the same as warn-insecure-code.sh (PreToolUse), which catches
# specific dangerous patterns. This hook detects security-SENSITIVE AREAS
# and recommends a thorough scan.
#
# Fires on: PostToolUse → Edit|Write
# Exit 0 + stdout = inject SAST suggestion
# Exit 0 + no output = not security-sensitive code
#
# Test: echo '{"tool_name":"Write","tool_input":{"file_path":"routes/api.js","content":"app.post(\"/login\", (req, res) => { })"}}' | .claude/hooks/suggest-sast-review.sh
# =============================================================================
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

# Only check source code files
FILENAME=$(basename "$FILE_PATH")
EXT="${FILENAME##*.}"
case "$EXT" in
  js|jsx|ts|tsx|py|go|java|kt|rb|php|rs|cs|scala) ;;
  *) exit 0 ;;
esac

# Skip hook/rule/skill infrastructure files
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

# Detect security-sensitive code areas (NOT specific vulnerabilities)
AREAS=""

# API endpoint / route handler creation
if echo "$CONTENT" | grep -qP '(app\.(get|post|put|delete|patch|use)\s*\(|@app\.route|@(Get|Post|Put|Delete|Patch)Mapping|http\.Handle(Func)?|router\.(get|post|put|delete)|@(Controller|RestController|RequestMapping))' 2>/dev/null; then
  AREAS="${AREAS}, API endpoints"
fi

# Authentication / authorization logic
if echo "$CONTENT" | grep -qiP '(authenticate|authorize|login|logout|signup|register|verify_token|jwt\.|passport\.|bcrypt|argon2|session\.(create|destroy)|middleware.*auth)' 2>/dev/null; then
  AREAS="${AREAS}, authentication/authorization"
fi

# Database query construction
if echo "$CONTENT" | grep -qiP '(\.query\(|\.execute\(|\.raw\(|SELECT\s+|INSERT\s+INTO|UPDATE\s+.*SET|DELETE\s+FROM|createQueryBuilder|EntityManager|ActiveRecord|\.where\()' 2>/dev/null; then
  AREAS="${AREAS}, database queries"
fi

# File I/O with potential user input
if echo "$CONTENT" | grep -qiP '(readFile|writeFile|open\s*\(|file_get_contents|fopen|os\.(Open|Create|ReadFile)|ioutil\.ReadFile)' 2>/dev/null; then
  AREAS="${AREAS}, file operations"
fi

# Request/response handling (user input processing)
if echo "$CONTENT" | grep -qiP '(req\.(body|params|query|headers)|request\.(form|args|json|data|GET|POST)|r\.FormValue|c\.Param|@RequestBody|@RequestParam|\$_(GET|POST|REQUEST|COOKIE))' 2>/dev/null; then
  AREAS="${AREAS}, user input handling"
fi

if [[ -z "$AREAS" ]]; then
  exit 0
fi

# Trim leading comma-space
AREAS="${AREAS#, }"

cat <<EOF
[HOOK: Security-Sensitive Code Written]
File: $FILE_PATH
Areas: $AREAS

This code touches security-sensitive functionality. Consider running /endor-sast for static analysis to catch potential vulnerabilities (injection, broken access control, data exposure).
EOF

exit 0
