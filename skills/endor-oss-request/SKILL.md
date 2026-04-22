---
name: endor-oss-request
description: >
  Trigger ingestion and analysis of a specific open source package version via
  an Endor Labs OSS dependency request. Use when the user says "trigger OSS
  dependency request", "request ingestion of <pkg>", "ingest this package",
  "add this OSS version to Endor", or wants Endor Labs to analyze a package
  version that isn't yet in the platform. Do NOT use for scanning local code
  (/endor-scan) or checking an already-ingested package (/endor-check).
---

# Endor Labs OSS Dependency Request

Trigger ingestion and analysis of a specific OSS package version so Endor Labs
can analyze it. Backed by `POST /v1/namespaces/{ns}/oss-dependency-requests`.

## Input Parsing

Extract from user input:

1. **Package + version** (required) — e.g., `org.apache.velocity:velocity@1.6.4-atlassian-39`, `lodash@4.17.21`
2. **Ecosystem** (required) — auto-detect from package name or ask
3. **Namespace** (required) — use `ENDOR_NAMESPACE` if set, otherwise ask

## Workflow

### Step 1: Build the package URL (PURL)

| Ecosystem | Verified PURL scheme | Example |
|-----------|----------------------|---------|
| Maven | `mvn://` | `mvn://org.apache.velocity:velocity@1.6.4-atlassian-39` |

For ecosystems not listed, ask the user for the exact PURL format — do not
invent a scheme.

### Step 2: Resolve the source repository clone URL

The request requires `source_repository_http_clone_url`. Try to discover it
before asking the user.

**Maven:** fetch the POM and read the `<scm>` block.

- Central: `https://repo1.maven.org/maven2/{group-slashes}/{artifact}/{version}/{artifact}-{version}.pom`
- Atlassian (`*-atlassian-*` versions): `https://maven.artifacts.atlassian.com/{group-slashes}/{artifact}/{version}/{artifact}-{version}.pom`

Extract `<scm>/<url>` or `<scm>/<connection>`. Normalize:

- Strip `scm:git:` / `scm:git:ssh://` prefixes
- Rewrite SSH to HTTPS: `git@github.com:org/repo.git` → `https://github.com/org/repo.git`
- Append `.git` if missing

If discovery fails, ask the user for the clone URL.

### Step 3: Infer `platform_source` from the URL host

| Host | `platform_source` |
|------|-------------------|
| `github.com` | `PLATFORM_SOURCE_GITHUB` |
| `bitbucket.org` | `PLATFORM_SOURCE_BITBUCKET` |
| `gitlab.com` | `PLATFORM_SOURCE_GITLAB` |
| other | Ask the user |

### Step 4: Confirm before creating

Show the full payload and ask for confirmation. This creates a resource in the
namespace and triggers ingestion.

### Step 5: Create via endorctl

```bash
npx -y endorctl api create -r OSSDependencyRequest -n <namespace> -d '{
  "meta": {"name": "trigger <pkg>@<version>"},
  "spec": {
    "dependencies": [{
      "name": "<purl>",
      "public": true,
      "platform_source": "<PLATFORM_SOURCE_*>",
      "source_repository_http_clone_url": "<clone-url>"
    }]
  }
}'
```

**Gotchas:**

- Resource name is **`OSSDependencyRequest`** (all caps `OSS`). `OssDependencyRequest` fails with `invalid resource`.
- Only `create` is supported. `list` returns `list operation not implemented for resource: OSSDependencyRequest`; `get` likewise.
- Requires write permission in the namespace (Code Scanner role or equivalent).

### Step 6: Report the result

Show the returned JSON (package PURL, namespace). Ingestion runs
asynchronously. Once analyzed, the package becomes queryable via
`/endor-check` and `/endor-score`.

## Error Handling

| Error | Action |
|-------|--------|
| `invalid resource: OssDependencyRequest` | Use `OSSDependencyRequest` (all caps) |
| `list operation not implemented` | Only `create` is supported for this resource |
| Invalid `platform_source` enum | Only `GITHUB`, `BITBUCKET`, `GITLAB` are known to work |
| Permission denied | User lacks write permission in the namespace |
| Auth error | Suggest `/endor-setup` |

## Safety

- Always confirm the payload with the user before creating the resource —
  OSS dependency requests affect the namespace.
- Do not fire duplicate requests for the same PURL in the same session.
