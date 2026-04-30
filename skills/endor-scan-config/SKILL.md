---
name: endor-scan-config
description: >
  Inspect the configuration that was used for past scans of an Endor Labs project --
  include/exclude paths, languages, enables, endorctl version, exit codes. Use when
  the user says "what include-paths did this project use", "which scans had SAST on",
  "why didn't file X get scanned", "scan config", "endor scan config", or wants to
  audit how scans were actually run for a project. Do NOT use for running a new scan
  (/endor-scan), viewing findings (/endor-findings), or managing policies (/endor-policy).
---

# Endor Labs Scan Config Inspector

Extract the *scan-time configuration* used for prior ScanResults of a project. Useful for debugging "why didn't X get scanned?" and auditing what flags/paths/languages a CI run actually used.

## Why this isn't a one-liner

`ScanResult.spec.environment.config` is a free-form JSON blob (a `google.protobuf.Struct`), not a typed proto message. That has two consequences:

1. **Field-masks die at the `config` boundary.** `--field-mask "spec.environment.config.scan_config.include_path"` is silently accepted but returns empty -- proto can't project keys *inside* a Struct.
2. **Keys inside `config` are PascalCase**, not snake_case (e.g. `ScanConfig.IncludePath`, not `scan_config.include_path`) -- they are Go struct field names serialized as JSON.

So: mask down to `spec.environment.config` server-side, then carve with `jq` using PascalCase paths.

## Workflow

### Step 1: Resolve the project

Need a project UUID. If the user gave a name, look it up first:

```bash
PROJECT_UUID=$(npx -y endorctl api list -r Project -n $ENDOR_NAMESPACE \
  --filter "meta.name==<project-name>" \
  --field-mask "uuid" -o json 2>/dev/null | jq -r '.list.objects[0].uuid')
```

### Step 2: Pull ScanResults for the project

Always filter by `meta.parent_kind==Project and meta.parent_uuid==$PROJECT_UUID`. Mask down to the typed boundary to keep the payload small (a full ScanResult includes findings, stats, ecosystem counts -- usually irrelevant for config inspection):

```bash
npx -y endorctl api list -r ScanResult -n $ENDOR_NAMESPACE \
  --filter "meta.parent_kind==Project and meta.parent_uuid==$PROJECT_UUID" \
  --field-mask "uuid,meta.create_time,spec.environment.config,spec.exit_code,spec.start_time,spec.end_time" \
  -o json 2>/dev/null
```

Note: `--field-mask "spec.environment.config.scan_config.*"` does NOT work -- it returns `config: {}`. Mask only as far as `spec.environment.config`.

### Step 3: Carve out the fields the user asked for

Common config fields under `spec.environment.config` (PascalCase):

| jq path | Meaning | endorctl flag |
|---------|---------|---------------|
| `.ScanConfig.IncludePath` | Path-based include filters | `--include-path` |
| `.ScanConfig.ExcludePath` | Path-based exclude filters | `--exclude-path` |
| `.ScanConfig.Include` | Package/file include patterns | `--include` |
| `.ScanConfig.Exclude` | Package/file exclude patterns | `--exclude` |
| `.ScanConfig.Languages` | Languages enabled for this scan | `--languages` |
| `.ScanConfig.Enables` | Optional scanners enabled (e.g. `secrets`, `ghactions`) | `--enable` |
| `.ScanConfig.QuickScan` | Whether reachability was skipped | `--quick-scan` |
| `.ScanConfig.SastIncludeTestFiles` | SAST scanned test files | `--sast-include-test-files` |
| `.ScanConfig.Path` | Working directory for the scan | `--path` |
| `.ToolChainsConfig.IncludePaths` | Toolchain-specific includes | toolchain config |
| `.endorctl_version` | endorctl binary version that ran the scan | -- |
| `.os` / `.arch` / `.num_cpus` / `.memory` | Runner environment | -- |

Example -- show include/exclude paths across all scans:

```bash
npx -y endorctl api list -r ScanResult -n $ENDOR_NAMESPACE \
  --filter "meta.parent_kind==Project and meta.parent_uuid==$PROJECT_UUID" \
  --field-mask "uuid,meta.create_time,spec.environment.config" \
  -o json 2>/dev/null \
  | jq -r '.list.objects[] | {
      uuid,
      created: .meta.create_time,
      include: .spec.environment.config.ScanConfig.Include,
      include_path: .spec.environment.config.ScanConfig.IncludePath,
      exclude: .spec.environment.config.ScanConfig.Exclude,
      exclude_path: .spec.environment.config.ScanConfig.ExcludePath
    }'
```

Example -- only scans that *actually used* path filters:

```bash
... | jq '.list.objects[] | select(.spec.environment.config.ScanConfig.IncludePath != null or .spec.environment.config.ScanConfig.ExcludePath != null)'
```

Example -- unique include-paths across the project's history:

```bash
... | jq -r '.list.objects[].spec.environment.config.ScanConfig.IncludePath[]?' | sort -u
```

### Step 4: Present results

Lead with the *answer to the question asked* (e.g. "this project has 12 scans, 3 of which used `--include-path`"), then show the per-scan breakdown only if it's small. For projects with many scans, summarize unique values.

```markdown
## Scan Config for {project-name}

**Total scans:** {N}
**Scans with path filters:** {M}
**endorctl versions seen:** {list}

### Unique include-paths
- {path1}
- {path2}

### Unique exclude-paths
- {path1}

### Per-scan (most recent first)
| Scan UUID | Date | endorctl | include-path | exclude-path |
|-----------|------|----------|--------------|--------------|
| ...       | ...  | ...      | ...          | ...          |
```

## Gotchas

- **Empty `Include`/`IncludePath` is the common case** -- most scans run without path filters. Don't report "no data" if the field is `null`; report "no path filters were configured for any scan."
- **A project can have many ScanResults** (one per CI run, branch, PR). Add `--page-size N` and `--sort-order descending --sort-path meta.create_time` for the most recent first, or paginate with `--list-all` if the user wants the full history.
- **Sub-namespaces:** if the project's scans live in child namespaces, add `--traverse` to the `endorctl api list` call.
- **Don't try to be clever with field-masks past `config`** -- it's a Struct; everything inside is opaque to proto. Mask to `spec.environment.config` and `jq` from there.

## Safety

- Read-only -- this skill never creates, updates, or deletes resources.
- The `config` blob can include CI-supplied values (commit SHAs, PR URLs, branch names). It is not expected to contain secrets, but if the user's `--data` or env piped a token in, treat the output as sensitive and don't paste it into shared logs.

## Related

- `/endor-api` -- generic API queries when you need a resource other than ScanResult.
- `/endor-findings` -- view *results* of a scan, not its config.
- `/endor-troubleshoot` -- when a scan failed or behaved unexpectedly.
