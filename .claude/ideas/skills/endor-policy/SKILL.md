---
name: endor-policy
description: |
  Create, view, and manage security policies for automated enforcement. Define rules for blocking PRs, requiring reviews, and enforcing security standards.
  - MANDATORY TRIGGERS: endor policy, security policy, create policy, policy management, enforcement policy, endor-policy, block critical, policy gate
---

# Endor Labs Policy Management

Create and manage security policies for automated enforcement.

## Prerequisites

- Endor Labs MCP server configured (run `/endor-setup` if not)
- Node.js v18+ with `npx` available
- Admin access to the Endor Labs namespace

## Policy Types

| Type | Purpose |
|------|---------|
| Finding Policy | Define what security issues to flag or block |
| Exception Policy | Create exceptions for accepted risks |
| Action Policy | Automate responses (block PR, notify, create ticket) |

## Available Policy Templates

| Template | Description |
|----------|-------------|
| `block-critical-reachable` | Block PRs with critical reachable vulnerabilities |
| `license-compliance` | Block copyleft licenses in commercial projects |
| `sast-required` | Require SAST scan pass before merge |
| `no-secrets` | Block any committed secrets |
| `sbom-required` | Require SBOM generation on release |
| `dependency-age` | Warn on dependencies older than N months |
| `max-severity` | Block findings above a severity threshold |

## Workflow

### Action: List Policies

Query existing policies:

```bash
npx -y endorctl api list --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null
```

Present results:

```markdown
## Active Security Policies

| # | Policy | Type | Action | Status |
|---|--------|------|--------|--------|
| 1 | Block Critical Reachable | Finding | Block PR | Active |
| 2 | License Compliance | Finding | Warn | Active |
| 3 | No Secrets | Finding | Block PR | Active |
```

### Action: Create Policy

#### Template: block-critical-reachable

This policy blocks PRs that introduce critical reachable vulnerabilities.

```bash
npx -y endorctl api create --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": {
    "name": "block-critical-reachable",
    "description": "Block PRs with critical reachable vulnerabilities"
  },
  "spec": {
    "finding_policy": {
      "type": "FINDING_POLICY_TYPE_BLOCK",
      "filter": "spec.level==FINDING_LEVEL_CRITICAL and spec.finding_tags contains FINDING_TAGS_REACHABLE_FUNCTION"
    }
  }
}'
```

#### Template: license-compliance

```bash
npx -y endorctl api create --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": {
    "name": "license-compliance",
    "description": "Block strong copyleft licenses"
  },
  "spec": {
    "finding_policy": {
      "type": "FINDING_POLICY_TYPE_BLOCK",
      "filter": "spec.finding_categories contains FINDING_CATEGORY_LICENSE_RISK and spec.level in [FINDING_LEVEL_CRITICAL, FINDING_LEVEL_HIGH]"
    }
  }
}'
```

#### Template: no-secrets

```bash
npx -y endorctl api create --resource FindingPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": {
    "name": "no-secrets",
    "description": "Block any exposed secrets"
  },
  "spec": {
    "finding_policy": {
      "type": "FINDING_POLICY_TYPE_BLOCK",
      "filter": "spec.finding_categories contains FINDING_CATEGORY_SECRETS"
    }
  }
}'
```

#### Template: max-severity

Ask the user for the maximum allowed severity, then create the policy accordingly.

#### Custom Policy

If the user wants a custom policy, help them build the filter using the filter reference from `/endor-findings`.

### Action: Create Exception

Create an exception for an accepted risk:

```bash
npx -y endorctl api create --resource ExceptionPolicy -n $ENDOR_NAMESPACE 2>/dev/null --data '{
  "meta": {
    "name": "exception-{finding-id}",
    "description": "{reason for exception}"
  },
  "spec": {
    "exception_policy": {
      "finding_uuid": "{finding_uuid}",
      "expiration": "{ISO-8601 date}",
      "justification": "{business justification}"
    }
  }
}'
```

### Present Policy Creation

```markdown
## Policy Created

**Name:** {policy_name}
**Type:** {Finding/Exception/Action}
**Action:** {Block/Warn/Notify}
**Status:** Active

### Filter

{Human-readable description of what this policy catches}

### What This Policy Does

{Description of the policy's effect}

### Next Steps

1. **Test policy:** Push a test commit to verify enforcement
2. **Add to CI/CD:** `/endor-cicd` to integrate with your pipeline
3. **View all policies:** `/endor-policy list`
4. **Create exception:** `/endor-policy exception {finding-id}`
```

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for policy or security information.** All data MUST come from Endor Labs MCP tools or the `endorctl` CLI. Do NOT search the web or visit external sources. If data is unavailable, tell the user and suggest [app.endorlabs.com](https://app.endorlabs.com).

## Error Handling

- **Insufficient permissions**: Suggest contacting the namespace admin
- **Policy already exists**: Offer to update or create with a different name
- **Invalid filter**: Help the user fix the filter syntax
- **Auth error**: Suggest `/endor-setup`
