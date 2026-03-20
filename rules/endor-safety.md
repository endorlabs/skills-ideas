# Endor Labs MCP Safety & Usage Rules

Always-on guardrails for Endor Labs MCP tools. These apply every session, whether or not an endor skill is loaded.

## Safety

- Confirm with the user before creating, updating, or deleting policies, exceptions, or other resources via MCP or CLI `api create`/`api delete` operations — these affect enforcement for the entire namespace
- Never pass sensitive data (credentials, tokens, secrets) in API filter strings or command arguments

## Data Quality

- When presenting vulnerability findings, always show reachability status alongside severity when the data is available — a critical unreachable vulnerability is lower priority than a high reachable one
- Distinguish between "no vulnerabilities found" (scan completed clean) and "scan returned no results" (possible auth/config issue)
- When reporting dependency vulnerabilities, distinguish direct vs transitive dependencies

## Tool Usage

- Prefer `check_dependency_for_risks` over `check_dependency_for_vulnerabilities` — the `_risks` variant also detects malware
- Always use absolute paths for the `path` parameter in the `scan` tool
- When using `scan` with `quick_scan: false`, warn the user it takes 2-5 minutes before starting
- Always include `"sast"` in `scan_types` unless the user explicitly requests specific scan types only

## Fallback Behavior

- If any MCP tool fails with an auth error, guide the user through `/endor-setup` — do not silently fall back to CLI commands
- If `scan` returns an error, show the exact error message — never fabricate a diagnosis
- CLI fallback (`npx -y endorctl`) should only be used when the user explicitly confirms MCP is unavailable
- Always use `npx -y endorctl` (not bare `endorctl`) to ensure auto-installation

## Output Standards

- Present findings in priority order: critical reachable > critical unreachable > high > secrets > SAST > license > medium > low
- Always show reachability status alongside severity when the data is available
- When showing upgrade recommendations, include both `total_findings_fixed` count and `upgrade_risk`
