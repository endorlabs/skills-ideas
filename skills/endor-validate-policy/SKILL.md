---
name: endor-validate-policy
description: >
  Validate an Endor Labs policy against a project to test if it matches any findings.
  Use when the user says "validate policy", "test policy", "does this policy match",
  "endor validate", "check policy against project", or wants to verify that a policy
  (finding or exception) correctly targets findings in a specific project before
  enforcing it. Do NOT use for creating policies (/endor-policy) or viewing findings
  (/endor-findings).
---

# Endor Labs Policy Validation

Validate a policy against project data to confirm it matches the expected findings before enforcement.

## Input Parsing

Extract from user input:
1. **Policy identifier** (required) — one of:
   - Policy UUID (e.g., `69de807f2b1bacdc078462e9`)
   - Path to a policy file (JSON, YAML, or plain Rego)
2. **Project identifier** (required) — one of:
   - Project UUID (e.g., `69de7d2281aeff029f3fb926`)
   - Project filter string (e.g., `meta.name contains my-project`)
3. **Optional modifiers:**
   - PR scan UUID — validate against a specific PR scan
   - PR baseline — name of baseline version for PR comparison
   - All releases — validate against all official releases
   - Input file — JSON file with template parameter values
   - Output format — json, yaml, or table (default: table)

## Workflow

### Step 1: Resolve Identifiers

If the user provides names instead of UUIDs, resolve them:

```bash
# Look up project UUID by name
endorctl api list --resource Project --filter "meta.name contains '{name}'" --field-mask "uuid,meta.name" 2>/dev/null
```

```bash
# Look up policy UUID by name
endorctl api list --resource Policy --filter "meta.name contains '{name}'" --field-mask "uuid,meta.name" 2>/dev/null
```

### Step 2: Validate

**By policy UUID against a project:**
```bash
endorctl validate policy --policy-uuid "{POLICY_UUID}" --uuid "{PROJECT_UUID}" 2>&1
```

**By policy UUID against a PR scan:**
```bash
endorctl validate policy --policy-uuid "{POLICY_UUID}" --uuid "{PROJECT_UUID}" --pr-uuid "{PR_UUID}" 2>&1
```

**By policy UUID with PR baseline:**
```bash
endorctl validate policy --policy-uuid "{POLICY_UUID}" --uuid "{PROJECT_UUID}" --pr-baseline "{BASELINE}" 2>&1
```

**By policy UUID against all releases:**
```bash
endorctl validate policy --policy-uuid "{POLICY_UUID}" --uuid "{PROJECT_UUID}" --all-releases 2>&1
```

**From a policy file:**
```bash
endorctl validate policy --policy "{FILE_PATH}" --uuid "{PROJECT_UUID}" 2>&1
```

**Plain Rego with custom query:**
```bash
endorctl validate policy --policy "{REGO_FILE}" --uuid "{PROJECT_UUID}" \
  --query "data.packagename.match_finding" \
  --resource-kinds "Finding,PackageVersion" 2>&1
```

**With template parameter input file:**
```bash
endorctl validate policy --policy-uuid "{POLICY_UUID}" --uuid "{PROJECT_UUID}" \
  --input "{INPUT_FILE}" 2>&1
```

**JSON output for programmatic parsing:**
```bash
endorctl validate policy --policy-uuid "{POLICY_UUID}" --uuid "{PROJECT_UUID}" -o json 2>&1
```

### Step 3: Present Results

#### If Policy Matches Findings

```markdown
## Policy Validation: PASS (matches found)

**Policy:** {policy_name} (`{policy_uuid}`)
**Project:** {project_name} (`{project_uuid}`)

### Matched Findings

| Finding UUID | Vulnerability | Severity | Package |
|-------------|---------------|----------|---------|
| {uuid} | {cve/ghsa} | {level} | {package} |

### Summary
- **Total matches:** {count}
- **Policy type:** {exception/finding/action}
- **Effect:** {what the policy will do when enforced}
```

#### If Policy Does Not Match

```markdown
## Policy Validation: NO MATCH

**Policy:** {policy_name} (`{policy_uuid}`)
**Project:** {project_name} (`{project_uuid}`)

No findings in this project match the policy criteria.

### Possible Reasons
- The targeted vulnerability may not exist in this project's dependencies
- Filter criteria (severity, relationship, scope) may be too narrow
- Project may not have been scanned yet

### Next Steps
1. `/endor-findings` — View project findings to compare
2. `/endor-policy` — Review or adjust policy criteria
3. `/endor-scan` — Re-scan the project
```

## Error Handling

| Error | Action |
|-------|--------|
| Policy not found | Verify UUID or file path; list policies with `/endor-policy` |
| Project not found | Verify UUID; list projects with `/endor-api` |
| Invalid Rego | Show syntax error from output; suggest fixing the rule |
| Auth error | Suggest `/endor-setup` |
| No scan data | Project may need scanning first; suggest `/endor-scan` |

For data source policy, read `references/data-sources.md`.
