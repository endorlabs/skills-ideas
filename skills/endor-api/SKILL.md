---
name: endor-api
description: >
  Execute custom queries against the Endor Labs API for advanced use cases. Use when
  the user asks to query findings, projects, packages, or metrics directly, says
  "endor api", "raw api query", "custom query", "list resources", or needs to run
  API filters not covered by other endor skills. Do NOT use for standard scanning
  (/endor-scan), dependency checks (/endor-check), or finding display (/endor-findings).
---

# Endor Labs Direct API Access

Execute custom queries against the Endor Labs API.

## API Endpoints

Base URL: `https://api.endorlabs.com`

| Endpoint | Description |
|----------|-------------|
| `GET /v1/namespaces/{ns}/findings` | Query findings |
| `GET /v1/namespaces/{ns}/projects` | List projects |
| `GET /v1/namespaces/{ns}/package-versions` | Package versions |
| `GET /v1/namespaces/oss/metrics` | OSS package metrics |
| `POST /v1/namespaces/{ns}/version-upgrades` | Upgrade analysis |
| `GET /v1/namespaces/{ns}/version-upgrades/{uuid}` | Upgrade results |

## Workflow

### Step 1: Understand the Query

Parse the user's request for:
1. **Resource type**: findings, projects, packages, metrics, etc.
2. **Filter**: severity, category, package, date, etc.
3. **Output**: what data to return

### Step 2: Execute Query

**MCP Tools (preferred):**

| MCP Tool | Use For |
|----------|---------|
| `scan` | Scan repo for vulnerabilities, secrets, SAST, dependencies |
| `get_resource` | Retrieve any resource by UUID or name |
| `check_dependency_for_vulnerabilities` | Check a package version for known CVEs |
| `check_dependency_for_risks` | Check a package for vulnerabilities AND malware (prefer over above) |
| `get_endor_vulnerability` | Get detailed CVE/GHSA info |
| `security_review` | AI-powered code diff security review (Enterprise only) |

**CLI (for operations not covered by MCP):**

```bash
npx -y endorctl api list --resource {Resource} -n $ENDOR_NAMESPACE --filter "{filter}" 2>/dev/null
npx -y endorctl api get --resource {Resource} -n $ENDOR_NAMESPACE --uuid {uuid} 2>/dev/null
npx -y endorctl api create --resource {Resource} -n $ENDOR_NAMESPACE --data '{json}' 2>/dev/null
```

For CLI parsing gotchas, read `references/cli-parsing.md`.

**Common Resource Types:** Finding, Project, PackageVersion, DependencyMetadata, FindingPolicy, ExceptionPolicy, RepositoryScan

### Step 3: Filter Syntax

```
field==value                          # Equality
field contains value                  # Contains
field not contains value              # Not contains
field1==value1 and field2==value2     # AND
field in [value1, value2]             # In list
field > value / field < value         # Comparison
```

**Filter examples:**

```bash
# Critical reachable vulnerabilities
--filter "spec.level==FINDING_LEVEL_CRITICAL and spec.finding_tags contains FINDING_TAGS_REACHABLE_FUNCTION"

# Findings for a project
--filter "spec.project_uuid=={project_uuid}"

# Projects by name
--filter "meta.name contains '{name}'"

# Package metrics (use oss namespace)
npx -y endorctl api list --resource Metric -n oss \
  --filter "meta.name==package_version_scorecard and meta.parent_uuid=={pkg_uuid}" 2>/dev/null
```

### Step 3.5: Field-Mask Gotcha -- the Struct Boundary

`--field-mask` only works on **typed proto fields**. Some resources have free-form JSON blobs (`google.protobuf.Struct` / `Any`) whose contents are opaque to proto. Field-masks behave differently at that boundary:

- **Outside a Struct:** an invalid path errors loudly (`ERROR invalid-args: mask: proto: invalid path "..." for message ...`).
- **Past a Struct boundary:** a path is silently accepted but returns an empty container -- the server projects up to the typed field and stops.

**Tell-tale signs you've hit a Struct:**
- The keys inside are **PascalCase** (e.g. `ScanConfig`, `IncludePath`) instead of typed proto **snake_case** (`scan_config`, `include_path`). PascalCase = a Go struct serialized into an untyped JSON container.
- A deeper field-mask returns `{}` for that field instead of an error.

**Workaround:** mask down to the typed boundary, then carve with `jq` using PascalCase paths.

Known Struct fields:
| Resource | Struct field | Carve with jq |
|----------|--------------|---------------|
| `ScanResult` | `spec.environment.config` | `.ScanConfig.IncludePath`, `.ScanConfig.Languages`, etc. |

Example -- get include-paths from ScanResults (full recipe in `/endor-scan-config`):

```bash
npx -y endorctl api list -r ScanResult -n $ENDOR_NAMESPACE \
  --filter "meta.parent_kind==Project and meta.parent_uuid=$PROJECT_UUID" \
  --field-mask "uuid,spec.environment.config" -o json 2>/dev/null \
  | jq '.list.objects[] | {uuid, include_path: .spec.environment.config.ScanConfig.IncludePath}'
```

Do NOT try `--field-mask "spec.environment.config.scan_config.include_path"` -- it returns `config: {}`.

### Step 4: Present Results

```markdown
## API Query Results

**Resource:** {resource_type}
**Filter:** {filter}
**Results:** {count}

### Data

{Formatted table or structured output}
```

For Finding field paths, read `references/cli-parsing.md`.

For data source policy, read `references/data-sources.md`.

## Error Handling

| Error | Action |
|-------|--------|
| Invalid filter syntax | Show correct syntax with examples |
| Resource not found | Verify resource type and namespace |
| Permission denied | Check namespace access |
| Auth error | Suggest `/endor-setup` |
| Rate limited | Wait and retry, or reduce page size |

## Safety

- Read operations (list/get) by default
- Create/update/delete require explicit user confirmation
- Never pass sensitive data in filter strings
