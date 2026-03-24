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

- If `scan` returns an error, show the exact error message — never fabricate a diagnosis
- CLI fallback (`npx -y endorctl`) should only be used when the user explicitly confirms MCP is unavailable
- Always use `npx -y endorctl` (not bare `endorctl`) to ensure auto-installation

## Authentication Workflows

Two mutually exclusive auth workflows exist. Using both simultaneously causes an error loop where `endorctl` finds two valid auth sources and cannot resolve which to use.

| Workflow | Auth Source | Setup | When to Use |
|----------|-----------|-------|-------------|
| **Local Development** | `~/.endorctl/config.yaml` (API key) | `endorctl init` | Single namespace, stable local dev |
| **Multi-Namespace** | Env vars in `settings.json` / `mcp.json` | Set `ENDOR_MCP_SERVER_AUTH_MODE`, `ENDOR_NAMESPACE`, `ENDOR_API` | Frequent namespace switching, no local config file |

**Never mix both.** If `config.yaml` exists, there must be no auth env vars (`ENDOR_MCP_SERVER_AUTH_MODE`, `ENDOR_NAMESPACE`, `ENDOR_API`) in `settings.json`/`mcp.json`. If auth env vars are set, there must be no `config.yaml`.

## Authentication Conflict Detection

Before any auth recovery attempt, check for the dual-source conflict:

1. Check if `~/.endorctl/config.yaml` exists: `test -f ~/.endorctl/config.yaml && echo "exists"`
2. Check if `settings.json` or `mcp.json` contains auth env vars: look for `ENDOR_MCP_SERVER_AUTH_MODE`, `ENDOR_NAMESPACE`, or `ENDOR_API` in the MCP server `env` block

**If BOTH are present** — this is the conflict. Do not attempt to re-authenticate until it is resolved:

1. Tell the user: "Authentication conflict detected — both a config file (`~/.endorctl/config.yaml`) and environment variables in your MCP settings are providing auth credentials. This causes an error loop."
2. Ask which workflow they want:
   - **Local Development**: keep `config.yaml`, remove auth env vars from `settings.json`
   - **Multi-Namespace**: remove `config.yaml`, keep env vars in `settings.json`
3. Apply the chosen cleanup, then proceed with auth recovery below.

## Authentication Recovery

If any `endorctl` command or MCP tool fails with an auth/credentials error (e.g. "no credentials found", "invalid permissions", token expired), do NOT stop and suggest `/endor-setup`. Instead, handle it inline:

1. **Run conflict detection first** (see above). If a conflict is found, resolve it before continuing.
2. **Determine the active workflow:**
   - If `~/.endorctl/config.yaml` exists (and no auth env vars) → **Local Development** workflow
   - If auth env vars are set in `settings.json` (and no `config.yaml`) → **Multi-Namespace** workflow
   - If neither exists → ask the user which workflow to set up (see Authentication Workflows table)
3. **Recover based on workflow:**
   - **Local Development**: Run `npx -y endorctl init --auth-mode=<MODE>` to refresh the config.yaml. Ask user for auth mode (`google`, `github`, `api-key`) and namespace if needed.
   - **Multi-Namespace**: Verify env vars are correct in `settings.json`. Ask user to confirm `ENDOR_MCP_SERVER_AUTH_MODE` and `ENDOR_NAMESPACE` values. Restart MCP connection.
4. Once authenticated, continue with the original workflow — do not ask the user to restart.

## Output Standards

- Present findings in priority order: critical reachable > critical unreachable > high > secrets > SAST > license > medium > low
- Always show reachability status alongside severity when the data is available
- When showing upgrade recommendations, include both `total_findings_fixed` count and `upgrade_risk`
