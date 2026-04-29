# endor-reports — User Guide

Generate Endor Labs security and compliance reports by chatting with Claude. No API keys, no scripts to write — authenticate once with `endorctl init` and ask Claude in plain English.

This guide is for humans. (`SKILL.md` next door is for Claude.)

---

## Prerequisites

| Item | What you need |
|---|---|
| `endorctl` | Installed and authenticated. Run `endorctl init` once in your terminal — it opens a browser for SSO. After that, your session is reused automatically. |
| Claude Code | Latest version, with the `endor-reports` skill available (your Endor Labs contact will set this up). |
| Namespace access | At least one Endor Labs namespace where you have read access to findings. |

You do **not** need an API token, a `.env` file, or any other credential. The skill rides on top of your existing `endorctl` session.

---

## First five minutes

1. Open Claude Code in a directory where the `endor-reports` skill is available.
2. Type:
   > Generate a remediation report for last month
3. Claude will ask which Endor namespace to use (only the first time per session). Answer with the namespace name (e.g., `acme-corp.gh-acme`, `prod-tenant`, `acme-tenant`).
4. Wait a few seconds. Claude tells you how many findings were exported and where the CSV is.
5. Open the CSV in Excel, Google Sheets, Numbers, or any tool that reads UTF-8 CSV.

That's it. The rest of this guide is variations.

---

## Prompting patterns (best practices)

### Be specific about dates

Vague date asks force Claude to ask follow-up questions. Specific dates produce reports immediately.

| Less specific (works, but slower) | More specific (better) |
|---|---|
| "Give me last month's remediations" | "Generate a remediation report for March 2026" |
| "Recent fixes" | "Remediations from the last 30 days" |
| "This year" | "Year-to-date remediations" |

Date phrases Claude understands without follow-up:

- **Calendar month:** "April 2026", "March 2026", "for last month", "for the previous month"
- **Calendar quarter:** "Q1 2026", "Q2", "last quarter"
- **Year-to-date:** "year-to-date", "YTD", "since the start of the year"
- **Rolling windows:** "last 7 days", "last 30 days", "last 90 days"
- **Calendar week:** "this week", "last week"
- **Explicit ISO dates:** "between 2026-01-01 and 2026-03-31"

### Scope to a project (optional)

Reports default to every project in the namespace. To narrow:

> Generate a remediation report for April 2026, just for project UUID abc123abc123abc123abc123

If you only know the project name, ask Claude:

> What's the UUID for the model-distilbert project?

(Claude will look it up via `endorctl`.)

### Choose where the file lands

| Phrase | Result |
|---|---|
| (nothing — you don't say) | `~/.claude/endor-reports/output/remediation_<timestamp>.csv` (default) |
| "Save to ~/Downloads" | `~/Downloads/remediation_<timestamp>.csv` (auto-named) |
| "Save to /tmp/april.csv" | exactly `/tmp/april.csv` (your name) |
| "Save it next to my project" | Claude picks a sensible path, tells you what it picked |

### Namespace switching

Claude remembers the namespace within a session. To switch mid-conversation:

> Switch to the prod-tenant namespace and re-run that for May

---

## Sample workflows

### Monthly executive review

> Generate a remediation report for last month and save it to ~/Documents/endor-monthly

You get one CSV in `~/Documents/endor-monthly/`. Open it, drop into a pivot table or charting tool, send.

### Quarterly comparison

> Generate two remediation reports — one for Q1 2026 and one for Q2 2026 — save them to ~/Documents with the quarter in the filename

Claude runs the runner twice with different date windows and `--output` paths.

### Project owner spot-check

> List the projects in this namespace
> → Claude calls `endorctl api list -r Project` and shows you the names + UUIDs

> Generate a remediation report for the top three by remediation count, last 90 days

Claude figures out the date math, runs three reports.

### Compliance evidence

> Pull every remediation between 2026-01-01 and 2026-03-31, save to /tmp/q1-evidence.csv

Audit-friendly: explicit dates, explicit destination, single file.

### Discovery

> What reports can you generate?
> → Claude lists `remediation` (today) and notes that more sources are coming.

> What columns does the remediation report include?
> → Claude prints the source YAML so you can see fetched_fields and column definitions.

> How do I use this?
> → Claude shows the example-prompts table from `SKILL.md`.

---

## What you'll get

The remediation report (CSV) contains one row per remediated finding — i.e., a finding that was closed in the date range you specified.

| Column | What it is | Example |
|---|---|---|
| Finding Log UUID | Unique ID of the log entry | `69dfd2210db88bf006219be5` |
| Finding UUID | ID of the underlying finding | `69dfd221c28de12740624da2` |
| Type | Category label | `dependency_with_high_severity_vulnerabilities`, `bad_license` |
| Description | Human summary | For SCA: `GHSA-jr5f-v2jv-69x6: axios Requests Vulnerable…`. For license: `License Risk in Dependency uri-js@4.4.1` |
| Severity | Finding level | `FINDING_LEVEL_HIGH`, `FINDING_LEVEL_CRITICAL` |
| Ecosystem | Package ecosystem | `ECOSYSTEM_PYPI`, `ECOSYSTEM_NPM`, `ECOSYSTEM_GO` |
| Package | Package + version | `pypi://mlflow@3.0.1`, `npm://lodash@4.17.21` |
| Resolved At | Date the finding was closed | `2026-04-15` |
| Introduced At | Date the finding first appeared | `2026-03-12` |
| Project UUID | Parent project ID | `def456def456def456def456` |
| Tags | Pipe-separated tag list | `FINDING_TAGS_REACHABLE_FUNCTION\|FINDING_TAGS_FIX_AVAILABLE` |

CSV is RFC 4180 compliant (UTF-8, LF line endings, properly quoted commas). Opens cleanly in Excel, Google Sheets, pandas, R, etc.

---

## Tips

- **Vague dates work, specific dates work better.** "Last month" requires no follow-up; "recent" usually does.
- **Empty results are still results.** If you get a CSV with just a header row, no findings were remediated in that window — confirm in the Endor UI before assuming a bug.
- **Large windows can stream a lot.** Tens of thousands of remediations across a year is normal for big organizations. Claude will tell you the row count when done. If you only need a sample, use a tighter window.
- **The CSV is the source of truth.** Filter, pivot, and chart in your spreadsheet tool of choice — v0.5 doesn't slice the report at the CLI level.
- **Re-running is free.** No rate-limit penalty for asking again with different parameters.

---

## Current limitations (v0.5)

This is the first usable release. Each item below is planned for v1:

- **PDF output** — formatted reports with charts and branded layout
- **More report types** — PR policy outcomes, active+remediated reconciliation, analytics dashboard exports, license-only reports, dependency reports
- **Saved recipes** — name a configuration once (`monthly-exec-review`), re-run by name
- **Scheduled reports** — generate automatically (e.g., first day of each month) via cron / launchd
- **Custom columns at runtime** — add or drop columns from the command without editing the source YAML
- **Server-side report jobs** — for analytics, the platform renders the report; we just download

If any of these are blockers for your use, let your Endor Labs contact know and we'll prioritize.

---

## Troubleshooting

| Symptom | What's happening | Fix |
|---|---|---|
| Claude says "needs_auth" or mentions `endorctl init` | Your endorctl session expired | Run `endorctl init` in your terminal (browser SSO), then ask Claude to retry |
| "needs_namespace" / "namespace could not be resolved" | You have access to multiple namespaces and didn't specify one | Tell Claude which namespace to use |
| "missing required parameter(s): start_date, end_date" | Your prompt didn't include a date range | Add a date phrase ("for April 2026", "year-to-date", explicit dates) |
| CSV has only a header row | No remediations in your date range — that's a fact, not a bug | Widen the window, or verify in the Endor UI |
| "endorctl error: …" | The Endor API rejected the request | Capture the error and share with your Endor Labs contact |
| Long delay before output | Streaming many pages of results | Wait it out — for tens of thousands of findings, expect 30–90 seconds |

---

## Output location reference

| Where | When |
|---|---|
| `~/.claude/endor-reports/output/<source>_<UTC_timestamp>.csv` | default — when you don't specify `--output` or `--output-dir` |
| `<your-dir>/<source>_<UTC_timestamp>.csv` | when you say "save to `<dir>`" |
| Exactly your path | when you say "save to `<full-path>.csv`" |

Timestamps are UTC, formatted `YYYYMMDD_HHMMSS` (e.g., `20260430_143200`).

---

## Getting help during a session

Three asks Claude is trained to handle:

> What reports can you generate?

> How do I use this?

> Show me the remediation source

Or just ask naturally — the skill is designed for plain English, not flag-juggling.
