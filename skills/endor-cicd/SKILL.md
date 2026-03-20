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
