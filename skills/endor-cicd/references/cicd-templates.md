# CI/CD Platform Templates

## Table of Contents
1. GitHub Actions
2. GitLab CI
3. Jenkins
4. Azure DevOps
5. Bitbucket Pipelines
6. CircleCI

---

## GitHub Actions

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

---

## GitLab CI

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

---

## Jenkins

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

---

## Azure DevOps

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

---

## Bitbucket Pipelines

```yaml
- step:
    name: Endor Labs Security Scan
    script:
      - curl -sL https://api.endorlabs.com/download/latest/endorctl_linux_amd64 -o endorctl
      - chmod +x endorctl
      - ./endorctl scan --path . --output-type summary
```

---

## CircleCI

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
