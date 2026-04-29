# `endor-reports` Skill — Design Spec

**Date:** 2026-04-29
**Status:** Approved (brainstorm phase) — pending implementation plan
**Author:** brainstorm session, lmoreno + Claude

## 1. Purpose

Provide a Claude Code skill (`endor-reports`) that generates Endor Labs security and compliance reports (CSV / PDF) on demand or on a schedule, with:

- **Uniform auth** via the user's existing `endorctl` session (no API tokens / secrets in the interactive flow).
- **Customizable column sets and filters** that escalate cleanly from "tweak the projection" to "widen the underlying data fetch" to "switch fetch modes."
- **Saved recipes** for repeatable invocations.
- **Single, stable subprocess shape** so one `.claude/settings.json` allowlist line covers every variant — no per-run permission prompts.
- **Local-only scheduling** for v1 (cron / launchd), zero secrets.

The skill replaces / unifies the four reference scripts in `endor-internal/scripts/`:

- `pr_block_warn_report` — PR policy outcomes
- `monthly_findings_report` — active + remediated findings reconciliation
- `analytics_pdf_report_from_csv` — analytics JSON → PDF
- `generate_remediation_report` — remediated findings (finding-logs)

The reference scripts are not deleted by v1 — they remain as fallback. v1 is functional parity through the skill; later phases can deprecate them.

## 2. Architecture

### 2.1 Layout

```
skills/endor-reports/
  SKILL.md                              # Claude-facing instructions (~150–200 lines)
  run.py                                # single CLI entry point — the only allowlisted command
  sources/
    pr_policy.yaml
    remediation.yaml
    findings_active_fixed.yaml
    analytics.yaml
  lib/
    endorctl_client.py                  # auth probe, list/create/get/download wrappers, pagination
    projection.py                       # column add/drop/rename, filter/sort on in-memory records
    enrichments.py                      # ghsa_to_cve cache, ecosystem_label, reachability_tag, ...
    renderers/
      csv.py
      pdf/
        frame.py                        # cover, header/footer, page management
        sections.py                     # summary_cards, donut, bar, line, stacked_area, table, kv_block
        palette.py                      # Endor brand colors + severity/reachability palettes
      passthrough.py                    # Path C: write platform-rendered artifact as-is (v2)
    adapters/
      json_to_pdf.py                    # Path B: platform JSON → RenderContext → PDF
  templates/
    assets/endor_logo.png
    pr_policy_pdf.py                    # declares which sections appear in the PDF
    remediation_pdf.py
    findings_active_fixed_pdf.py
    analytics_pdf.py
  .claude/settings.json                 # ships with tight per-command allowlist

~/.claude/endor-reports/                # user-scoped runtime state
  recipes/<name>.yaml                   # named saved configurations
  last/<source>.yaml                    # auto-saved on every successful run
  output/                               # default output directory
  logs/                                 # scheduled-run log files
```

### 2.2 Three data paths

```
PATH A — api_list (most v1 reports)
  endorctl api list -r <Resource> --filter '...' --field-mask '...'
  → records → enrichments → projection → CSV / PDF (frame+sections)

PATH B — api_job + post_process (analytics in v1)
  endorctl api create -r Job + poll + download platform JSON
  → adapter (json_to_pdf) → RenderContext → PDF (frame+sections, same as Path A)

PATH C — api_job, passthrough (v2: findings_pdf, dependencies, license)
  endorctl api create -r Job + poll + download platform artifact
  → write to output dir AS-IS (no rendering layer)
```

### 2.3 v1 source inventory

| Source | Mode | Path | Output |
|---|---|---|---|
| `pr_policy` | `api_list` | A | CSV + optional PDF |
| `remediation` | `api_list` | A | CSV |
| `findings_active_fixed` | `api_list` | A | CSV + optional PDF |
| `analytics` | `api_job` | B | PDF (post-processed from JSON) |

### 2.4 v2 source candidates (not in v1, documented only)

- `findings_pdf` — `JOB_TYPE_FINDINGS_REPORT`, Path C
- `dependencies` — `JOB_TYPE_DEPENDENCIES_REPORT`, Path C
- `license` — `JOB_TYPE_LICENSE_REPORT`, Path C

These are bonuses surfaced by the proto survey; they require Path C wiring (passthrough renderer + content-type validation) which is deferred.

## 3. Source YAML schema

### 3.1 Common header (every source)

```yaml
name: <stable id>
description: <one-liner used in --list-sources>
modes: [api_list]                   # or [api_job], or both
default_mode: api_list
default_format: [csv]               # csv | pdf | both
parameters:
  - name: <param_name>
    type: date | string | bool | int
    required: true | false
    default: <value>                # optional
```

### 3.2 `api_list` block

```yaml
api_list:
  resource: Finding | FindingLog | ScanResult | Project | ...
  filter_template: |                # Mustache-style; references parameters
    spec.operation == "OPERATION_DELETE"
    and meta.update_time >= "{{start_date}}"
    {{#if project_uuid}}and spec.project_uuid == "{{project_uuid}}"{{/if}}
  fetched_fields:                   # field mask sent to endorctl; widen target
    - meta.name
    - meta.update_time
    - spec.vulnerability.cve_id
    - ...
  default_columns:                  # projection applied after fetch
    - { header: "CVE ID", source: spec.vulnerability.cve_id, fallback: "missing" }
    - { header: "Resolved At", source: meta.update_time, format: iso_date }
  enrichments:                      # optional, declarative, run in-process
    - { kind: ghsa_to_cve, when: "cve_id == 'missing' and ghsa_id" }
    - { kind: ecosystem_label }
  pagination:
    page_size: 500
```

### 3.3 `api_job` block

```yaml
api_job:
  job_type: JOB_TYPE_ANALYTICS_REPORT
  request_type: type.googleapis.com/internal.endor.ai.endor.v1.AnalyticsReportJob.Request
  request_template:
    list_findings_filter: "{{findings_filter}}"
    list_finding_logs_filter: "{{logs_filter}}"
    list_projects_filter: "{{projects_filter}}"
    traverse: false
    report_type: REPORT_TYPE_JSON
  platform_column_universe: []      # empty for analytics; populated for FINDINGS / DEPENDENCIES
  poll: { interval_seconds: 5, timeout_seconds: 600 }
  post_process:                     # optional; only Path B uses this
    - { kind: json_to_pdf, template: templates/analytics_pdf.py }
```

For sources where `platform_column_universe` is populated (v2: `findings_pdf`, `dependencies`), the runner emits a `columns: { ... }` sub-message inside `request_template` at submission time.

## 4. Runner CLI (`run.py`)

### 4.1 Surface

```
run.py <source> [flags]
  --mode api_list|api_job
  --param key=value                       (repeatable)
  --since DATE --until DATE               (shorthand)
  --add-col HEADER=SOURCE[:transform]     (repeatable)
  --drop-col HEADER                       (repeatable)
  --filter "EXPR"                         (api_list: AND-appended; api_job: replaces a mapped param)
  --sort HEADER[:asc|desc]
  --format csv|pdf|both
  --output-dir DIR
  --output PATH                           (overrides --output-dir)
  --recipe NAME                           (load from ~/.claude/endor-reports/recipes/)
  --save-as NAME                          (persist resolved config as recipe)
  --namespace NS                          (override endorctl namespace)
  --dry-run                               (print resolved config; do not execute)
  --json                                  (structured output for non-interactive callers)
  --confirm-widen                         (proceed with widen without re-prompt; for re-invoke after user consent)
  --schedule --cron "EXPR" --via cron|launchd   (emit scheduling artifact)
  --list-sources
  --list-recipes
  --show-recipe NAME
```

### 4.2 Override precedence (low → high)

source YAML defaults → `--recipe` values → CLI flags

### 4.3 Four-tier widen-on-miss

When `--add-col HEADER=SOURCE` references a `SOURCE` path:

| Tier | Condition | Behavior |
|---|---|---|
| 1. Trivial | `api_list`, SOURCE in `fetched_fields` | Project immediately. No re-run. |
| 2. Widen | `api_list`, SOURCE not in `fetched_fields` | Interactive: confirm, append to `fetched_fields` in source YAML (git-tracked edit), re-invoke with `--confirm-widen`. Non-interactive: exit 2 with `needs_widening` payload. |
| 3. Platform-bound | `api_job`, SOURCE in `platform_column_universe` | Set `columns.<source> = true` in `request_template`. No re-run. |
| 4. Unavailable | `api_job`, SOURCE outside universe | Exit 2 with `unavailable_in_mode`; if source declares `api_list` too, suggest `--mode api_list`. |

Tier-2 widen edits the **source YAML in place**, making the new field permanent for all users (recipes can narrow further on top). This is a deliberate choice over recipe-only widening — it grows the source's capability over time rather than fragmenting it across recipes.

### 4.4 Auth pre-flight

```
1. endorctl auth status --json
2. If not authed → exit 2 with `needs_auth` payload (SKILL.md tells Claude to prompt user to run `endorctl init`)
3. If authed but namespace ambiguous → exit 2 with `needs_namespace` (unless --namespace given)
4. Otherwise proceed
```

The runner never invokes `endorctl init` itself — it's interactive (browser flow), and silent invocation in scheduled contexts would fail. SKILL.md handles the human handoff.

### 4.5 `api_list` fetch loop

```
1. Render filter_template (Mustache) using parameters → final filter expression
2. endorctl api list -r <Resource>
   --filter '<rendered>'
   --field-mask '<comma-joined fetched_fields>'
   --page-size <pagination.page_size>
   --output-format json
3. Stream pages until next_page_id is empty
4. Apply enrichments (in-process, with per-run caches)
5. Apply projection (default_columns + CLI add/drop/sort)
6. Hand to renderer
```

### 4.6 `api_job` submit + poll loop

```
1. Render request_template using parameters
2. endorctl api create -r Job --data '<rendered>'    → returns job uuid
3. Loop:
     endorctl api get -r Job <uuid>
     - JOB_STATE_SUCCESS → break, capture spec.response.payload.report_url
     - JOB_STATE_FAILED → exit 1 with spec.error_message
     - timeout reached → cancel + exit 1
     - else sleep poll.interval_seconds
4. Download via endorctl api download (or platform-documented helper)
   — never construct curl with embedded bearer token
5. If post_process declared, run pipeline (e.g., json_to_pdf adapter → PDF)
6. Place final artifact in output dir
```

### 4.7 Recipe + last-run persistence

Recipe schema (mirrors a resolved invocation, not the source YAML):

```yaml
source: remediation
mode: api_list
params: { start_date: 2026-04-01, end_date: 2026-04-30, project_uuid: null }
columns_add:
  - { header: "PR Author", source: spec.pr_author }
columns_drop: ["Days Unresolved"]
filter_extra: 'spec.finding_categories contains "FINDING_CATEGORY_VULNERABILITY"'
sort: "Resolved At:desc"
format: [csv, pdf]
namespace: prod-tenant
saved_at: 2026-04-29T14:22:00Z
saved_via: --save-as monthly-exec
```

Behavior:

- `--save-as NAME` → writes `recipes/<name>.yaml` (overwrite confirmation if exists)
- Every successful run → unconditionally writes `last/<source>.yaml` (overwrites prior)
- `--recipe NAME` → loads `recipes/<name>.yaml` as base config; CLI flags layer on top
- When `--recipe` is NOT specified and `last/<source>.yaml` exists, it acts as an implicit base (equivalent to `--recipe last/<source>`); CLI flags still layer on top normally. So `run.py <source>` re-runs the last invocation verbatim, and `run.py <source> --since 2026-01-01` re-runs the last invocation with only the date overridden.

### 4.8 Output path resolution

1. `--output PATH` → exact path; format inferred from extension or `--format`
2. `--output-dir DIR` → `<DIR>/<source>_<UTC_timestamp>.{csv,pdf}`
3. Fallback → `~/.claude/endor-reports/output/<source>_<UTC_timestamp>.{csv,pdf}`

When `--format both`, both files share the same basename.

### 4.9 Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Operational failure (network, auth refused, job failed, timeout) |
| 2 | Needs human input (`needs_auth`, `needs_namespace`, `needs_widening`, `unavailable_in_mode`) |

`--json` mode emits a structured payload on stdout for code 2; otherwise a human-readable message. No retries on 1; no auto-fixing on 2 (always re-prompt the user).

## 5. Rendering

### 5.1 CSV (Path A only)

- Header row from `[c.header for c in resolved_columns]`
- RFC 4180 quoting, UTF-8, LF line endings
- Stream-write — never load full result into memory
- Default fallback for missing values is empty string, not literal `None`

### 5.2 PDF — frame + pluggable sections (Paths A and B)

Frame (`templates/_frame.py`) provides:

- Cover page: logo, report title, generated-at timestamp, namespace, applied-filter block
- Per-page header (small logo + title) and footer (page N of M, namespace, timestamp)

Section primitives (composable, declared per-template):

- `summary_cards(metrics: dict)` — colored metric cards
- `donut(data, palette)` — distributions (severity, reachability)
- `bar(data, palette)` — categorical breakdowns
- `line(series)` / `stacked_area(series)` — time series
- `table(rows, columns, max_rows_per_page)` — paginated table with zebra rows + repeated header
- `kv_block(pairs)` — filter metadata, project info

Per-source PDF template declares which sections appear and their config:

```python
# templates/remediation_pdf.py
SECTIONS = [
    ("summary_cards", lambda d: {
        "Total Resolved": len(d),
        "Avg Days to Fix": d.avg("days_unresolved"),
        "Critical Fixed": d.count("severity == 'CRITICAL'"),
    }),
    ("donut", "severity"),
    ("kv_block", "applied_filters"),
    ("table", {"max_rows_per_page": 25}),
]
```

### 5.3 Brand palette (`renderers/pdf/palette.py`)

```
ENDOR_GREEN = "#00D26A"
ENDOR_DARK  = "#1A1A2E"
SEVERITY = { CRITICAL: "#D32F2F", HIGH: "#F57C00", MEDIUM: "#FBC02D",
             LOW: "#7CB342", INFO: "#90A4AE" }
REACHABILITY = { reachable: ENDOR_GREEN, unreachable: "#90A4AE", unknown: "#BDBDBD" }
```

Logo at `templates/assets/endor_logo.png`. Matplotlib forced to `Agg` backend (headless).

### 5.4 JSON → PDF adapter (`adapters/json_to_pdf.py`, Path B only)

```yaml
post_process:
  - kind: json_to_pdf
    template: templates/analytics_pdf.py
    json_schema_hints:
      vulnerabilities_path: data.vulnerabilities
      filters_path: data.metadata.filters
```

Adapter: load downloaded JSON → walk `schema_hints` → build a `RenderContext` matching the shape Path A's projection produces → hand to frame + sections. If the platform's JSON schema changes, only `schema_hints` and the adapter need updating; the frame and sections stay stable.

### 5.5 Pagination + size discipline

- Tables paginate at `max_rows_per_page`; header repeats on each page
- Templates can declare `orientation: landscape` for wide column sets (>8 columns)
- Charts emitted as PNG at `dpi=120` (predictable file size, not vector)
- Logo loaded once via reportlab's image cache
- Soft warn if PDF >5 MB, hard refuse at >25 MB (sign of pathological data or template bug)

## 6. SKILL.md (Claude-facing instructions)

### 6.1 Frontmatter

```yaml
---
name: endor-reports
description: Generate Endor Labs security/compliance reports (CSV/PDF) from endorctl data sources, with saved recipes and local scheduling. Use when the user asks for a report, monthly findings summary, remediation list, PR policy outcomes, analytics export, or wants to schedule a recurring report.
allowed-tools:
  - Bash(python skills/endor-reports/run.py:*)
  - Bash(endorctl auth status:*)
  - Bash(endorctl whoami:*)
  - Bash(endorctl api list:*)
  - Bash(endorctl api create -r Job:*)
  - Bash(endorctl api get -r Job:*)
  - Bash(endorctl api download:*)
  - Read
  - Write
---
```

### 6.2 Body sections

1. **What this skill does** — one paragraph, lists v1 sources, says outputs default to `~/.claude/endor-reports/output/`.
2. **Decision flow** — small diagram: did user ask for a report? → list sources → match intent → translate to `run.py` flags → invoke.
3. **Override translation table** — natural language → CLI flag, e.g.:
    - "last 30 days" → `--since $(...) --until $(...)`
    - "add a column for code owners" → `--add-col "Code Owners=spec.code_owners.owners"`
    - "drop the days unresolved column" → `--drop-col "Days Unresolved"`
    - "save this as monthly-exec" → `--save-as monthly-exec`
    - "use the saved monthly-exec" → `--recipe monthly-exec`
4. **Error response protocols** (one per exit-code-2 case):
    - `needs_auth` → tell user to run `endorctl init`, wait for confirmation, re-invoke
    - `needs_namespace` → ask user which namespace; pass `--namespace`
    - `needs_widening` → show missing field + diff; on user yes, re-invoke with `--confirm-widen`; on no, suggest `--mode api_list` if available
    - `unavailable_in_mode` → suggest the alternate mode if the source supports it
5. **Scheduling protocol** — see Section 7
6. **What this skill doesn't do** — no API tokens / `.env` / secrets; no merging of multiple sources into one report; no auto-installation of cron jobs (always shows the line and asks the user)

Target length: 150–200 lines. Long-form details live behind `run.py --list-sources` / `--help` / `--show-recipe`, not inlined.

### 6.3 Skill is purely a translator

Claude does not generate Python or write its own queries. Every report invocation is `run.py <source>` with flags. The skill teaches Claude how to translate user intent to flags and how to react to structured exit-code-2 errors. Nothing more.

## 7. Scheduling

### 7.1 v1: local only, no secrets

```
run.py --schedule [--cron "0 9 1 * *"] [--via cron|launchd]
```

| `--via` | Platform | Auth | Notes |
|---|---|---|---|
| `cron` | Linux / macOS | existing `endorctl init` session | machine must be awake at run time |
| `launchd` | macOS | existing `endorctl init` session | catches up missed runs if machine was asleep |

Both emit the install artifact + instructions; the user installs themselves. **No secrets are ever required by v1.** Outputs default to `~/.claude/endor-reports/output/`; logs go to `~/.claude/endor-reports/logs/<recipe>.log`.

### 7.2 Deferred / future scheduling work

Documented but not built in v1:

- **Routines (`/schedule`)** — Anthropic-hosted, requires `ENDOR_TOKEN` in routine environment. Viable when user wants hands-off cloud scheduling and accepts the secret tradeoff. Output goes to claude.ai sessions, optional PR commit, optional Slack via connector.
- **GitHub Actions** — repo workflow, requires `ENDOR_API_CREDENTIALS_KEY`/`SECRET` repo secrets. Viable for team-shared scheduled reports.
- **Desktop scheduled tasks** — local, similar to launchd but Claude-Code-native.

These are future options; they are NOT in scope for v1.

## 8. Permissions

### 8.1 Allowlist (`skills/endor-reports/.claude/settings.json`)

```json
{
  "permissions": {
    "allow": [
      "Bash(python skills/endor-reports/run.py:*)",
      "Bash(endorctl auth status:*)",
      "Bash(endorctl whoami:*)",
      "Bash(endorctl api list:*)",
      "Bash(endorctl api create -r Job:*)",
      "Bash(endorctl api get -r Job:*)",
      "Bash(endorctl api download:*)"
    ]
  }
}
```

### 8.2 Explicitly NOT allowlisted

- `Bash(endorctl init:*)` — interactive (opens browser); always confirmed with the user
- `Bash(endorctl api delete:*)` — never needed for reports
- Any raw `curl` — downloads go through `endorctl api download`, never bearer tokens in the shell

The single `run.py` allowlist line covers every report variant, every recipe, every override — addressing the "permission prompt every run" concern.

## 9. Out of scope for v1

- Routines, GHA, desktop-scheduled-tasks scheduling targets
- Path C (passthrough) sources: `findings_pdf`, `dependencies`, `license`
- Multi-source merged reports
- API-token-based auth (interactive uses endorctl session only)
- HTML, Markdown, XLSX output formats
- Delivery channels (email, Slack, PR comment) — outputs are local files only
- Deletion of the four reference scripts in `endor-internal/scripts/`

## 10. Success criteria for v1

1. User can run `python skills/endor-reports/run.py <source> [flags]` for all four v1 sources and get a CSV / PDF that matches the corresponding reference script's output shape.
2. Adding a column via `--add-col` works without re-prompting permissions, and triggers the widen flow when the field is outside `fetched_fields`.
3. `--save-as NAME` and `--recipe NAME` round-trip: a saved recipe re-runs identically when re-loaded.
4. `run.py --schedule --cron "..." --via cron` emits a working crontab line that, when installed, runs the report without re-authenticating.
5. A fresh checkout + first run prompts `needs_auth` cleanly, the user runs `endorctl init`, and the re-invoke succeeds.
6. The shipped `.claude/settings.json` allowlist eliminates per-run permission prompts in default Claude Code mode.

## 11. Open questions deferred to implementation plan

- Exact `endorctl` flag names for field-mask + JSON output — verify during implementation against installed endorctl version
- The download mechanism for `api_job` artifacts — `endorctl api download` vs. `endorctl api get -r File` vs. signed URL — verify against current platform API
- Whether `endorctl auth status --json` exists in all supported endorctl versions (fallback: parse `endorctl whoami`)
- Mustache vs. Jinja2 vs. simple string template for `filter_template` — pick during implementation; lean Mustache for safety (no code execution)
