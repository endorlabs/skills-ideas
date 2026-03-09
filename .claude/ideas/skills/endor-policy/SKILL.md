---
name: endor-policy
description: |
  Create, view, and manage security policies for automated enforcement. Define rules for blocking PRs, requiring reviews, and enforcing security standards.
  - MANDATORY TRIGGERS: endor policy, security policy, create policy, policy management, enforcement policy, endor-policy, block critical, policy gate
---

# Endor Labs Policy Management

Create and manage security policies. Requires admin access to the namespace.

## Policy Types

| Type | Purpose |
|------|---------|
| Finding Policy | Define what security issues to flag or block |
| Exception Policy | Create exceptions for accepted risks |
| Action Policy | Automate responses (block PR, notify, create ticket) |

## Templates

| Template | Description |
|----------|-------------|
| `block-critical-reachable` | Block PRs with critical reachable vulns |
| `license-compliance` | Block copyleft licenses in commercial projects |
| `no-secrets` | Block any committed secrets |
| `sast-required` | Require SAST scan pass before merge |
| `sbom-required` | Require SBOM generation on release |
| `dependency-age` | Warn on stale dependencies |
| `max-severity` | Block findings above severity threshold |

## Workflow

### List Policies

```bash
npx -y endorctl api list --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null
```

### Create Policy

#### block-critical-reachable
```bash
npx -y endorctl api create --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": { "name": "block-critical-reachable", "description": "Block PRs with critical reachable vulnerabilities" },
  "spec": { "finding_policy": { "type": "FINDING_POLICY_TYPE_BLOCK", "filter": "spec.level==FINDING_LEVEL_CRITICAL and spec.finding_tags contains FINDING_TAGS_REACHABLE_FUNCTION" } }
}'
```

#### license-compliance
```bash
npx -y endorctl api create --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": { "name": "license-compliance", "description": "Block strong copyleft licenses" },
  "spec": { "finding_policy": { "type": "FINDING_POLICY_TYPE_BLOCK", "filter": "spec.finding_categories contains FINDING_CATEGORY_LICENSE_RISK and spec.level in [FINDING_LEVEL_CRITICAL, FINDING_LEVEL_HIGH]" } }
}'
```

#### no-secrets
```bash
npx -y endorctl api create --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": { "name": "no-secrets", "description": "Block any exposed secrets" },
  "spec": { "finding_policy": { "type": "FINDING_POLICY_TYPE_BLOCK", "filter": "spec.finding_categories contains FINDING_CATEGORY_SECRETS" } }
}'
```

#### max-severity
Ask user for the maximum allowed severity, then build filter accordingly.

#### Custom Policy
Help user build filter using `/endor-findings` filter reference.

### Create Exception

```bash
npx -y endorctl api create --resource ExceptionPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": { "name": "exception-{finding-id}", "description": "{reason}" },
  "spec": { "exception_policy": { "finding_uuid": "{uuid}", "expiration": "{ISO-8601}", "justification": "{justification}" } }
}'
```

### Present Results

After creating/listing policies:

```markdown
## Policy Created

**Name:** {name} | **Type:** {type} | **Action:** {action} | **Status:** Active

### Filter
{Human-readable description}

### Next Steps
1. Push a test commit to verify enforcement
2. `/endor-cicd` — Integrate with pipeline
3. `/endor-policy list` — View all policies
```

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| Insufficient permissions | Contact namespace admin |
| Policy already exists | Offer to update or rename |
| Invalid filter | Help fix syntax |
| Auth error | Suggest `/endor-setup` |
