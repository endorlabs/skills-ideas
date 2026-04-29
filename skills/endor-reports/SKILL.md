---
name: endor-reports
description: Generate Endor Labs security/compliance reports (CSV) from endorctl data sources. Use when the user asks for a report, remediation list, monthly findings summary, or wants to export Endor data to a spreadsheet. v0.5 supports the `remediation` source only; other sources arrive in v1.
allowed-tools:
  - Bash(python skills/endor-reports/run.py:*)
  - Bash(endorctl auth status:*)
  - Bash(endorctl whoami:*)
  - Bash(endorctl api list:*)
  - Read
  - Write
---

# endor-reports

Generates CSV reports from Endor Labs data via the user's existing `endorctl` session. No API tokens, no `.env` files, no secrets — auth piggybacks on `endorctl init`.

> **For users (humans):** see `USAGE.md` for the human-facing user guide — prerequisites, prompting patterns, sample workflows, troubleshooting. If the user asks "where's the documentation?" or "how do I share this with my team?", point them at `skills/endor-reports/USAGE.md`.

## When to use

The user asks for any of:

- "remediation report", "fixed findings", "what got resolved last month"
- "monthly Endor report" / "Endor CSV" / "export Endor findings"
- "list of remediated CVEs"

## Available sources (v0.5)

Run `python skills/endor-reports/run.py --list-sources` to see the live list. Today: `remediation` only.

## Before the first invocation

`endorctl` may resolve to multiple namespaces for a single user. The runner can't pick one for them — it will return `needs_namespace` (exit 2) if it can't infer a default.

**Best practice:** at the start of a session, if the user hasn't specified a namespace AND you don't already know one from earlier in this conversation, ask once:

> "Which Endor Labs namespace should I use? (e.g., `acme-tenant`, `prod-tenant`, or your specific tenant like `acme-corp.ml-models`)"

Once you have the namespace, **remember it for subsequent invocations in the same session** — pass it as `--namespace <ns>` every time. Don't re-prompt for each report.

If the user said "use whatever default" or "just try it," go ahead without `--namespace`. The runner will succeed if there's a single namespace, otherwise it'll cleanly return `needs_namespace` and you can ask then.

## Invocation pattern

Always invoke through the runner — never write Python or call `endorctl api list` directly:

```bash
python skills/endor-reports/run.py <source> [flags]
```

### Translating user intent to flags

> **Tip:** see "Before the first invocation" above for the namespace-prompting flow.

| User says | Flags |
|---|---|
| "last month's remediated findings" | `--since <first day of last month> --until <last day of last month>` |
| "remediated findings between 2026-04-01 and 2026-04-30" | `--since 2026-04-01 --until 2026-04-30` |
| "for project UUID xyz" | `--param project_uuid=xyz` |
| "save to ~/Downloads/foo.csv" | `--output ~/Downloads/foo.csv` |
| "save to ~/Downloads" | `--output-dir ~/Downloads` |
| "use the prod-tenant namespace" | `--namespace prod-tenant` |

If the user does not specify dates, ask them — `--since` and `--until` are required.

## Error response protocols

The runner uses three exit codes:

- **0** — success. Tell the user where the file was written (the runner prints `wrote N rows to <path>`).
- **1** — operational failure (network error, endorctl error, source load error). Show the stderr message to the user; don't auto-retry.
- **2** — needs human input. Three cases in v0.5:
  - **`needs_auth`** — runner stderr will mention "not authenticated" or "Run `endorctl init`". Tell the user: *"You need to authenticate with endorctl first — please run `endorctl init` in your terminal (it'll open a browser), then ask me to retry."* Wait for the user to confirm they've authenticated, then re-invoke `run.py` with the same flags. **Do not try to run `endorctl init` yourself** — it's interactive and opens a browser; let the user run it.
  - **`needs_namespace`** — runner stderr says "namespace could not be resolved". Ask the user which namespace to use, then re-invoke with `--namespace <name>`.
  - **`missing required parameter(s)` or invalid `--param`** — runner stderr names the missing parameter (typically `start_date`/`end_date`). Re-ask the user for the missing value (for date params, the natural language → flag mapping in the table above is your reference) and re-invoke with the correct flag.

## Example prompts and expected behavior

When the user asks how to use this skill (e.g., "how do I use endor-reports?", "what can I ask?", "show me examples"), surface this table:

| User says | What you do |
|---|---|
| "Generate a remediation report for April 2026" | Confirm namespace, then run `run.py remediation --since 2026-04-01 --until 2026-04-30 --namespace <ns>` |
| "Save it to ~/Downloads" | Add `--output-dir ~/Downloads` to the invocation |
| "Save to /tmp/foo.csv" | Add `--output /tmp/foo.csv` to the invocation |
| "Just for project UUID 684a0ac5..." | Add `--param project_uuid=abc123abc123abc123abc123` |
| "Last month" / "previous month" / "in March" | Compute first/last day of the month, pass via `--since` and `--until` |
| "Year-to-date" / "Q1" / "last 30 days" | Compute the date range and pass via `--since`/`--until` |
| "What reports can you generate?" | Run `python skills/endor-reports/run.py --list-sources` |
| "Show me the remediation source" / "what columns?" | Run `python skills/endor-reports/run.py --show-source remediation` |
| "Generate a PDF" | Politely decline — v0.5 is CSV-only (planned for v1) |
| "Schedule this monthly" | Politely decline — scheduling arrives in v1 |
| "Add a column for X" | Politely decline — `--add-col` (widen-on-miss) is v1 |
| "How do I use this?" / "show me how" | Surface a summary of this table |

After a successful run, the runner prints `wrote N rows to <path>`. Always tell the user the row count and path so they can find the file.

## What this skill does NOT do (v0.5)

- PDF output (only CSV in v0.5)
- Other report types (only `remediation` in v0.5)
- Saved recipes (`--save-as` / `--recipe` arrive in v1)
- Scheduled runs (`--schedule` arrives in v1)
- Adding/dropping columns at the CLI (`--add-col` / `--drop-col` arrive in v1 with widen-on-miss support)
- API-token authentication — interactive use is `endorctl init`-only

If the user asks for any of the above, explain that it's planned for v1 and offer the v0.5 equivalent (e.g., default columns, manual cron line, single-shot invocation).

## Tool usage

- `Bash` is restricted to the allowlisted commands in frontmatter — every report invocation goes through `run.py`, never through ad-hoc shell.
- `Read` and `Write` are available for inspecting and (rarely) editing source YAMLs in `skills/endor-reports/sources/`. Don't edit source YAMLs unless the user explicitly asks — that's the v1 widen-flow's job.
