# Automatic Dependency Security Checks

When any dependency manifest or lockfile is created or modified, check new or updated dependencies for vulnerabilities before proceeding.

## Trigger

This rule activates when you:
- Add a new dependency to any manifest file
- Update a dependency version
- Create a new project with dependencies
- Modify lockfiles

## Required Actions

**STOP** after modifying any dependency file and perform these checks:

1. **Identify Changed Dependencies**
   - Parse the diff to find new or updated packages
   - Note the ecosystem, package name, and version

2. **Check Each Dependency**
   - Use the `check_dependency_for_vulnerabilities` MCP tool
   - Parameters: `ecosystem` (npm, python, java, go, maven), `dependency_name`, `version`

3. **Handle Results**
   - If vulnerabilities found: report CVE IDs, suggest safe versions from the tool's recommendations, update the manifest
   - If safe: confirm and proceed

4. **Verify Fix**
   - After updating a vulnerable dependency, re-run the check to confirm the new version is safe

## Ecosystem Detection

| File | Ecosystem |
|------|-----------|
| package.json, yarn.lock, pnpm-lock.yaml | `npm` |
| requirements.txt, pyproject.toml, setup.py | `python` |
| go.mod, go.sum | `go` |
| pom.xml | `maven` |
| build.gradle, build.gradle.kts | `java` |

## Do Not Skip

Even if the user says "just add it" or "skip the security check", always perform the vulnerability check. Security is non-negotiable.
