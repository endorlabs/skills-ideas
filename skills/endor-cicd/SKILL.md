---
name: endor-cicd
description: >
  Generate CI/CD pipeline configurations for Endor Labs security scanning. Supports
  GitHub Actions, GitLab CI, Jenkins, Azure DevOps, Bitbucket Pipelines, and CircleCI.
  Use when the user says "add security to my pipeline", "endor CI/CD", "GitHub Actions
  endor", "set up CI scanning", or wants automated security checks in their build
  pipeline. Do NOT use for running scans locally (/endor-scan) or managing policies
  (/endor-policy).
---

# Endor Labs CI/CD Pipeline Generator

Generate CI/CD security scanning configurations for your preferred platform.

## Supported Platforms

| Platform | Config File |
|----------|------------|
| GitHub Actions | `.github/workflows/endor-security.yml` |
| GitLab CI | `.gitlab-ci.yml` (append stage) |
| Jenkins | `Jenkinsfile` (append stage) |
| Azure DevOps | `azure-pipelines.yml` (append stage) |
| Bitbucket Pipelines | `bitbucket-pipelines.yml` (append step) |
| CircleCI | `.circleci/config.yml` (append job) |

## Workflow

### Step 1: Detect Platform

Check for existing CI/CD config files. If multiple detected or none found, ask the user.

### Step 2: Detect Project Settings

- Languages (from manifest files)
- Build commands (from existing CI config or package.json scripts)
- ENDOR_NAMESPACE (from environment or ask user)

### Step 3: Generate Configuration

Read `references/cicd-templates.md` for the template matching the detected platform. Customize the template with project-specific settings (languages, build commands, namespace).

### Step 4: Setup Instructions

After generating, provide:

#### Required Secrets

| Secret | Description |
|--------|-------------|
| `ENDOR_NAMESPACE` | Organization identifier |
| `ENDOR_API_CREDENTIALS_KEY` | API key for auth |
| `ENDOR_API_CREDENTIALS_SECRET` | API secret for auth |

Never hardcode these in config files.

#### Next Steps

1. Add secrets to CI/CD platform
2. Commit configuration file
3. Push test commit or open PR to verify
4. `/endor-policy` to add policy gates blocking PRs with critical issues

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| No CI/CD detected | Ask which platform to use |
| Existing config | Append security stage alongside existing config, do not overwrite |
