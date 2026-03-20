# CLI Parsing Reference

## Critical Rules
- Always use `2>/dev/null` when piping CLI output to JSON parser (stderr has progress/auth messages)
- `spec.remediation` is a **plain string** (e.g., `"Update to version X.Y.Z"`), NOT a nested object
- `spec.target_dependency_package_name` includes ecosystem prefix (e.g., `pypi://django@4.2`) — strip for display

## Finding Field Paths
- **Title**: `meta.description`
- **Severity**: `spec.level` (e.g., `FINDING_LEVEL_CRITICAL`)
- **CVE/GHSA ID**: `spec.extra_key` or `spec.finding_metadata.vulnerability.meta.name`
- **Package**: `spec.target_dependency_package_name` (strip ecosystem prefix)
- **Version**: `spec.target_dependency_version`
- **Categories**: `spec.finding_categories`
- **Tags**: `spec.finding_tags`
- **CVSS Score**: `spec.finding_metadata.vulnerability.spec.cvss_v3_severity.score`
- **Summary**: `spec.finding_metadata.vulnerability.spec.summary`

## CLI Response Structure
```json
{
  "list": {
    "objects": [{
      "uuid": "...",
      "meta": { "description": "GHSA-xxxx: Title" },
      "spec": {
        "level": "FINDING_LEVEL_CRITICAL",
        "extra_key": "GHSA-xxxx",
        "target_dependency_package_name": "pypi://pkg@1.0",
        "remediation": "Update to version 1.2.3",
        "finding_categories": ["FINDING_CATEGORY_VULNERABILITY"],
        "finding_tags": ["FINDING_TAGS_REACHABLE_FUNCTION"]
      }
    }]
  }
}
```
