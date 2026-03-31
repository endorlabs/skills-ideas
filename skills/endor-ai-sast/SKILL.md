---
name: endor-ai-sast
description: >
  Fetch and display AI-powered SAST findings from the Endor Labs platform. Use when the
  user says "AI SAST results", "AI SAST findings", "AI static analysis", "endor ai sast",
  "show AI SAST", or wants to view pre-computed AI-driven code security findings. Do NOT
  use for running a new SAST scan (/endor-sast), viewing general findings (/endor-findings),
  or explaining a specific CVE (/endor-explain).
---

# Endor Labs AI SAST Analysis

Fetch AI-powered static analysis security findings using pre-computed data from the Endor Labs platform.

## Prerequisites

- Endor Labs authenticated (run `/endor-setup` if not)

## Workflow

### Step 1: Resolve Namespace

Before making ANY `endorctl api` call, resolve the namespace.

```bash
export ENDOR_NAMESPACE="${ENDOR_NAMESPACE:-$(grep -E '^ENDOR_NAMESPACE:' ~/.endorctl/config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')}"
echo "ENDOR_NAMESPACE=$ENDOR_NAMESPACE"
```

If empty, run `/endor-setup` to authenticate and set the namespace.

### Step 2: Find the Project UUID

Get the git remote URL, then query for the project. **Only run this after Step 1 succeeds.**

```bash
GIT_URL=$(git remote get-url origin 2>/dev/null)
npx -y endorctl api list --resource Project -n $ENDOR_NAMESPACE \
  --filter "spec.git.http_clone_url=='$GIT_URL'" \
  --field-mask="uuid,meta.name" 2>&1 | tee /tmp/endor_list_project_output.txt
```

For CLI field paths and parsing gotchas, read references/cli-parsing.md.

Run this command ONCE with the exact git remote URL. Do NOT retry with URL variations. If the project is not found, see Error Handling.

### Step 3: Fetch AI SAST Findings

```bash
npx -y endorctl api list -r Finding -n $ENDOR_NAMESPACE \
  -f 'context.type == CONTEXT_TYPE_MAIN and spec.project_uuid == "{PROJECT_UUID}" and spec.method == SYSTEM_EVALUATION_METHOD_DEFINITION_AI_SAST' \
  --field-mask meta.description,spec.explanation,spec.dependency_file_paths,spec.level \
  2>&1 | tee /tmp/endor_sast_findings_output.txt
```

If the output is empty, respond with exactly: `"No AI SAST findings are available for this project at this moment."` — no further explanation.

### Step 4: Present Results

Parse the results from Step 3 and present a **Findings Summary** table with these five columns:

| Title | Finding Location | Severity | Summary | Data Flow |
|-------|-----------------|----------|---------|-----------|

- **Title**: value of `meta.description` — copy verbatim, do not modify
- **Finding Location**: value of `spec.dependency_file_paths`
- **Severity**: value of `spec.level`
- **Summary**: copy verbatim from `spec.explanation` — everything after `## Summary` up to (but not including) `## Data Flow`
- **Data Flow**: copy verbatim from `spec.explanation` — everything from `## Data Flow` to the end, including all Stage and Location fields

Sort rows: **Critical** > **High** > **Medium** > **Low**.

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| Auth error | Run `/endor-setup` |
| License/permission error | Inform user: "AI SAST requires an Endor Labs license. Visit [app.endorlabs.com](https://app.endorlabs.com) or contact your administrator." |
| Project not found | Run `/endor-scan` to onboard the project, then retry `/endor-ai-sast` |
| No findings | Show exact message: "No AI SAST findings are available for this project at this moment." |
