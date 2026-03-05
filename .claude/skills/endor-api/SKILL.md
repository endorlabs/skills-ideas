---
name: endor-api
description: |
  Execute custom queries against the Endor Labs API for advanced use cases. Provides direct access to findings, projects, packages, and metrics endpoints.
  - MANDATORY TRIGGERS: endor api, custom query, raw api, api query, endor-api, direct api, advanced query
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
| `get_endor_vulnerability` | Get detailed CVE/GHSA info |

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
