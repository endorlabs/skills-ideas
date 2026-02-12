---
name: endor-cicd
description: |
  Generate CI/CD pipeline configurations for security scanning with Endor Labs. Supports GitHub Actions, GitLab CI, Jenkins, Azure DevOps, Bitbucket Pipelines, and CircleCI.
  - MANDATORY TRIGGERS: endor cicd, endor ci, endor pipeline, github actions endor, gitlab ci endor, endor-cicd, security pipeline, ci cd security
---

# Endor Labs CI/CD Pipeline Generator

Generate CI/CD security scanning configurations for your preferred platform.

## Prerequisites

- Endor Labs account configured (run `/endor-setup` if not)
- Access to your CI/CD platform configuration

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

Check for existing CI/CD configuration files:

```
.github/workflows/ -> GitHub Actions
.gitlab-ci.yml -> GitLab CI
Jenkinsfile -> Jenkins
azure-pipelines.yml -> Azure DevOps
bitbucket-pipelines.yml -> Bitbucket Pipelines
.circleci/config.yml -> CircleCI
```

If multiple are detected or none found, ask the user which platform to use.

### Step 2: Detect Project Settings

- Programming languages (from manifest files)
- Build commands (from existing CI config or package.json scripts)
- ENDOR_NAMESPACE (from environment or ask user)

### Step 3: Generate Configuration

#### GitHub Actions

```yaml
name: Endor Labs Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write
  contents: read
  security-events: write

jobs:
  endor-security:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup endorctl
        uses: endorlabs/github-action/setup@main

      - name: Endor Labs Scan
        uses: endorlabs/github-action/scan@main
        with:
          namespace: ${{ secrets.ENDOR_NAMESPACE }}
          sarif_file: endor-findings.sarif
          pr: ${{ github.event_name == 'pull_request' }}
          enable_github_action_token: true

      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: endor-findings.sarif

      - name: SBOM Export (main only)
        if: github.ref == 'refs/heads/main'
        run: |
          endorctl sbom export --format cyclonedx --output sbom.json
        env:
          ENDOR_NAMESPACE: ${{ secrets.ENDOR_NAMESPACE }}

      - name: Upload SBOM
        if: github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.json
```

#### GitLab CI

```yaml
endor-security:
  stage: test
  image: ubuntu:latest
  before_script:
    - curl https://api.endorlabs.com/download/latest/endorctl_linux_amd64 -o endorctl
    - chmod +x endorctl
    - mv endorctl /usr/local/bin/
  script:
    - endorctl scan --path . --output-type summary
  variables:
    ENDOR_NAMESPACE: $ENDOR_NAMESPACE
  rules:
    - if: $CI_MERGE_REQUEST_ID
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  artifacts:
    reports:
      sast: endor-findings.json
```

#### Jenkins

```groovy
stage('Endor Labs Security') {
    steps {
        sh '''
            curl -sL https://api.endorlabs.com/download/latest/endorctl_linux_amd64 -o endorctl
            chmod +x endorctl
            ./endorctl scan --path . --output-type summary
        '''
    }
    environment {
        ENDOR_NAMESPACE = credentials('endor-namespace')
    }
}
```

#### Azure DevOps

```yaml
- stage: Security
  jobs:
    - job: EndorScan
      pool:
        vmImage: 'ubuntu-latest'
      steps:
        - script: |
            curl -sL https://api.endorlabs.com/download/latest/endorctl_linux_amd64 -o endorctl
            chmod +x endorctl
            ./endorctl scan --path . --output-type summary
          env:
            ENDOR_NAMESPACE: $(ENDOR_NAMESPACE)
          displayName: 'Endor Labs Security Scan'
```

#### Bitbucket Pipelines

```yaml
- step:
    name: Endor Labs Security Scan
    script:
      - curl -sL https://api.endorlabs.com/download/latest/endorctl_linux_amd64 -o endorctl
      - chmod +x endorctl
      - ./endorctl scan --path . --output-type summary
```

#### CircleCI

```yaml
endor-security:
  docker:
    - image: cimg/base:stable
  steps:
    - checkout
    - run:
        name: Install endorctl
        command: |
          curl -sL https://api.endorlabs.com/download/latest/endorctl_linux_amd64 -o endorctl
          chmod +x endorctl
          sudo mv endorctl /usr/local/bin/
    - run:
        name: Endor Labs Scan
        command: endorctl scan --path . --output-type summary
        environment:
          ENDOR_NAMESPACE: ${ENDOR_NAMESPACE}
```

### Step 4: Setup Instructions

After generating the configuration, provide setup steps:

```markdown
## Setup Instructions

### 1. Add Secrets

Add the following secrets to your CI/CD platform:

| Secret | Value | Description |
|--------|-------|-------------|
| `ENDOR_NAMESPACE` | Your Endor Labs namespace | Organization identifier |
| `ENDOR_API_CREDENTIALS_KEY` | API key | For authentication |
| `ENDOR_API_CREDENTIALS_SECRET` | API secret | For authentication |

**Important:** Never hardcode these values in configuration files.

### 2. Add Configuration

{Instructions specific to the platform}

### 3. Verify

Push a test commit or open a PR to verify the scan runs successfully.

### Next Steps

1. **Add policy gates:** `/endor-policy` to block PRs with critical issues
2. **Generate SBOM:** Already included for main branch builds
3. **View findings:** Results appear in Endor Labs dashboard
```

## Data Sources — Endor Labs Only

**CRITICAL: NEVER use external websites for CI/CD configuration examples or security pipeline guidance.** All pipeline templates MUST be based on Endor Labs documentation and the `endorctl` CLI. Do NOT search the web for pipeline examples. If additional guidance is needed, suggest [docs.endorlabs.com](https://docs.endorlabs.com).

## Error Handling

- **No CI/CD detected**: Ask the user which platform they use
- **Existing config**: Suggest adding the security stage alongside existing config rather than overwriting
