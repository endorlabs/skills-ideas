# `endor-reports` v0.5 Implementation Plan — Remediation Source End-to-End

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working slice of the `endor-reports` skill: one source (`remediation`) generating a CSV via the `api_list` data path, invoked through `run.py`, with auth pre-flight, source YAML loading, filter template rendering, paginated `endorctl api list` fetch, column projection, and CSV output. Proves the architecture before expanding to PDF, other sources, scheduling, and recipes.

**Architecture:** Single Python entry point (`run.py`) reads a YAML-defined source, performs `endorctl auth status` pre-flight, renders a Mustache-style filter expression, calls `endorctl api list -r FindingLog` with pagination, projects records to columns, and writes a CSV. Permission allowlist in `.claude/settings.json` covers every variant via the stable `python skills/endor-reports/run.py:*` pattern.

**Tech Stack:** Python 3.11+, `pyyaml`, `pytest`, stdlib `csv` / `argparse` / `subprocess` / `pathlib` / `re`. No external HTTP libs in v0.5 (auth + data both go through `endorctl` subprocess).

**Spec reference:** [`docs/superpowers/specs/2026-04-29-endor-reports-design.md`](../specs/2026-04-29-endor-reports-design.md). Sections 2 (architecture), 3 (source YAML schema — common header + `api_list` block), 4.1 / 4.4 / 4.5 / 4.8 / 4.9 (CLI surface, auth pre-flight, `api_list` fetch loop, output resolution, exit codes), 5.1 (CSV renderer), 6 (SKILL.md), 8 (allowlist).

**v0.5 explicitly excludes (deferred to v1 plan):**
PDF rendering, the other 3 sources (`pr_policy`, `findings_active_fixed`, `analytics`), `api_job` mode, scheduling (`--schedule`), saved recipes (`--save-as` / `--recipe`), implicit `last/<source>.yaml` re-run, widen-on-miss column overrides (`--add-col` / `--drop-col`), enrichments (`ghsa_to_cve` lookup, `ecosystem_label`, `reachability_tag`), the `--dry-run` flag (defer), and `--json` structured exit-code-2 payloads (v0.5 emits human-readable errors only).

**Background context for the engineer (zero-context-friendly):**

`endorctl` is the Endor Labs CLI. We rely on the user having authenticated previously via `endorctl init` (browser flow). Once authed, `endorctl auth status` reports the current user/namespace, and `endorctl api list -r <Resource> --filter '<expr>' --field-mask <fields> --page-size <N>` returns JSON. Pagination uses a `next_page_id` cursor in responses; subsequent calls add `--page-token <id>`. We never embed bearer tokens — every API call goes through `endorctl`.

Source YAMLs in `sources/` declare a resource, a Mustache-style filter template referencing parameters (e.g. `{{start_date}}`), the field mask to fetch, and the default column projection. The runner reads a source, resolves parameters from CLI flags, renders the filter, fetches records page by page, projects to columns, and writes a CSV.

---

## File Structure

**New files (all under `skills/endor-reports/`):**

| Path | Responsibility |
|---|---|
| `requirements.txt` | Python deps (pyyaml, pytest) |
| `pytest.ini` | pytest config (testpaths, async mode off) |
| `.claude/settings.json` | Permission allowlist (single `run.py` line + endorctl verbs) |
| `run.py` | CLI entry: argparse, dispatch, `api_list` pipeline orchestration |
| `lib/__init__.py` | (empty package marker) |
| `lib/filter_template.py` | Mustache-style template renderer (`{{var}}`, `{{#if var}}...{{/if}}`) |
| `lib/source_loader.py` | YAML parser + dataclass model for source files |
| `lib/projection.py` | Apply `default_columns` projection to records (nested path lookup, fallback, formatter) |
| `lib/output.py` | Resolve output path from CLI flags + source name |
| `lib/endorctl_client.py` | Subprocess wrappers for `endorctl auth status` and `endorctl api list` (paginated streaming) |
| `lib/renderers/__init__.py` | (empty package marker) |
| `lib/renderers/csv.py` | RFC 4180 streaming CSV writer |
| `sources/remediation.yaml` | First source: remediated findings (`FindingLog` + `OPERATION_DELETE`) |
| `SKILL.md` | Skill instructions for Claude (frontmatter + body) |
| `tests/__init__.py` | (empty package marker) |
| `tests/conftest.py` | Shared pytest fixtures (sample records, tmp output dirs, mocked subprocess) |
| `tests/fixtures/finding_log_page1.json` | Sample `endorctl api list -r FindingLog` page 1 |
| `tests/fixtures/finding_log_page2.json` | Sample page 2 (final page, no `next_page_id`) |
| `tests/fixtures/auth_status_ok.json` | Sample `endorctl auth status --json` (authed) |
| `tests/fixtures/auth_status_unauthed.txt` | Sample non-zero output when not authed |
| `tests/test_filter_template.py` | Tests for filter template renderer |
| `tests/test_source_loader.py` | Tests for YAML source loader |
| `tests/test_projection.py` | Tests for projection module |
| `tests/test_output.py` | Tests for output path resolution |
| `tests/test_endorctl_client.py` | Tests for auth probe + paginated list (mocked subprocess) |
| `tests/test_csv_renderer.py` | Tests for CSV writer |
| `tests/test_run_integration.py` | End-to-end smoke test: invoke `run.py remediation` with mocked `endorctl` |

**Why this decomposition:** each `lib/*.py` module owns one responsibility with a clear interface (input → output). The runner orchestrates them; modules don't import the runner. Tests mirror module boundaries one-to-one. The single integration test at the end exercises the full pipeline with a fully-mocked `endorctl` binary, proving wiring without requiring a live Endor account.

---

## Task 1: Skill scaffold + permission allowlist + requirements

**Files:**
- Create: `skills/endor-reports/requirements.txt`
- Create: `skills/endor-reports/pytest.ini`
- Create: `skills/endor-reports/.claude/settings.json`
- Create: `skills/endor-reports/lib/__init__.py`
- Create: `skills/endor-reports/lib/renderers/__init__.py`
- Create: `skills/endor-reports/tests/__init__.py`
- Create: `skills/endor-reports/tests/fixtures/.gitkeep`

- [ ] **Step 1: Create the skill directory tree**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
mkdir -p skills/endor-reports/lib/renderers
mkdir -p skills/endor-reports/sources
mkdir -p skills/endor-reports/tests/fixtures
mkdir -p skills/endor-reports/.claude
```

- [ ] **Step 2: Write `requirements.txt`**

File: `skills/endor-reports/requirements.txt`

```
pyyaml>=6.0
pytest>=7.4
```

- [ ] **Step 3: Write `pytest.ini`**

File: `skills/endor-reports/pytest.ini`

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_functions = test_*
addopts = -v --strict-markers
```

- [ ] **Step 4: Write `.claude/settings.json` with the v0.5 allowlist**

File: `skills/endor-reports/.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Bash(python skills/endor-reports/run.py:*)",
      "Bash(endorctl auth status:*)",
      "Bash(endorctl whoami:*)",
      "Bash(endorctl api list:*)"
    ]
  }
}
```

Note: `endorctl api create -r Job` and `endorctl api download` are not allowlisted in v0.5 — they're added in v1 when `api_job` ships.

- [ ] **Step 5: Create empty package markers**

```bash
touch skills/endor-reports/lib/__init__.py
touch skills/endor-reports/lib/renderers/__init__.py
touch skills/endor-reports/tests/__init__.py
touch skills/endor-reports/tests/fixtures/.gitkeep
```

- [ ] **Step 6: Set up Python venv and install deps**

```bash
cd skills/endor-reports
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate
```

Add `.venv/` to `.gitignore` if not already covered:

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
grep -q '^skills/endor-reports/.venv' .gitignore 2>/dev/null || echo 'skills/endor-reports/.venv/' >> .gitignore
```

- [ ] **Step 7: Verify pytest runs (with no tests yet)**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest
```

Expected: exit code 5 (`no tests ran`) — that's success for an empty test suite.

- [ ] **Step 8: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/ .gitignore
git commit -m "feat(endor-reports): scaffold skill directory + permission allowlist"
```

---

## Task 2: Test fixtures (sample endorctl payloads)

**Files:**
- Create: `skills/endor-reports/tests/fixtures/finding_log_page1.json`
- Create: `skills/endor-reports/tests/fixtures/finding_log_page2.json`
- Create: `skills/endor-reports/tests/fixtures/auth_status_ok.json`
- Create: `skills/endor-reports/tests/fixtures/auth_status_unauthed.txt`
- Create: `skills/endor-reports/tests/conftest.py`

These fixtures stand in for live `endorctl` output during unit and integration tests. Field shapes mirror what the real CLI returns; values are illustrative.

- [ ] **Step 1: Write `finding_log_page1.json` (2 records, has `next_page_id`)**

File: `skills/endor-reports/tests/fixtures/finding_log_page1.json`

```json
{
  "list": {
    "objects": [
      {
        "uuid": "fl-uuid-001",
        "meta": {
          "name": "remediation-001",
          "update_time": "2026-04-10T14:30:00Z",
          "create_time": "2026-04-10T14:30:00Z"
        },
        "spec": {
          "operation": "OPERATION_DELETE",
          "finding_uuid": "f-uuid-001",
          "project_uuid": "abc123abc123abc123abc123",
          "vulnerability": {
            "cve_id": "CVE-2025-12345",
            "ghsa_id": "GHSA-aaaa-bbbb-cccc"
          },
          "finding_summary": "Critical RCE in libfoo",
          "finding_level": "FINDING_LEVEL_CRITICAL",
          "finding_categories": ["FINDING_CATEGORY_VULNERABILITY"],
          "finding_tags": ["FINDING_TAGS_REACHABLE_FUNCTION", "FINDING_TAGS_FIX_AVAILABLE"]
        }
      },
      {
        "uuid": "fl-uuid-002",
        "meta": {
          "name": "remediation-002",
          "update_time": "2026-04-15T09:00:00Z",
          "create_time": "2026-03-01T09:00:00Z"
        },
        "spec": {
          "operation": "OPERATION_DELETE",
          "finding_uuid": "f-uuid-002",
          "project_uuid": "abc123abc123abc123abc123",
          "vulnerability": {
            "cve_id": "",
            "ghsa_id": "GHSA-xxxx-yyyy-zzzz"
          },
          "finding_summary": "Prototype pollution in libbar",
          "finding_level": "FINDING_LEVEL_HIGH",
          "finding_categories": ["FINDING_CATEGORY_VULNERABILITY"],
          "finding_tags": ["FINDING_TAGS_FIX_AVAILABLE"]
        }
      }
    ],
    "response": {
      "next_page_id": "PAGE2_TOKEN"
    }
  }
}
```

- [ ] **Step 2: Write `finding_log_page2.json` (1 record, terminal page — no `next_page_id`)**

File: `skills/endor-reports/tests/fixtures/finding_log_page2.json`

```json
{
  "list": {
    "objects": [
      {
        "uuid": "fl-uuid-003",
        "meta": {
          "name": "remediation-003",
          "update_time": "2026-04-20T11:45:00Z",
          "create_time": "2026-02-01T11:45:00Z"
        },
        "spec": {
          "operation": "OPERATION_DELETE",
          "finding_uuid": "f-uuid-003",
          "project_uuid": "abc123abc123abc123abc123",
          "vulnerability": {
            "cve_id": "CVE-2024-99999",
            "ghsa_id": "GHSA-pppp-qqqq-rrrr"
          },
          "finding_summary": "SQL injection in libbaz",
          "finding_level": "FINDING_LEVEL_MEDIUM",
          "finding_categories": ["FINDING_CATEGORY_VULNERABILITY"],
          "finding_tags": []
        }
      }
    ],
    "response": {}
  }
}
```

- [ ] **Step 3: Write `auth_status_ok.json`**

File: `skills/endor-reports/tests/fixtures/auth_status_ok.json`

```json
{
  "user": "lmoreno@endor.ai",
  "namespace": "acme-tenant",
  "authenticated": true,
  "expires_at": "2026-05-29T12:00:00Z"
}
```

- [ ] **Step 4: Write `auth_status_unauthed.txt` (raw stderr from unauth'd `endorctl`)**

File: `skills/endor-reports/tests/fixtures/auth_status_unauthed.txt`

```
Error: not authenticated. Run `endorctl init` to authenticate.
```

- [ ] **Step 5: Write shared `conftest.py` fixtures**

File: `skills/endor-reports/tests/conftest.py`

```python
"""Shared pytest fixtures for endor-reports tests."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

FIXTURE_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture
def fixture_dir() -> Path:
    return FIXTURE_DIR


@pytest.fixture
def finding_log_page1() -> dict:
    return json.loads((FIXTURE_DIR / "finding_log_page1.json").read_text())


@pytest.fixture
def finding_log_page2() -> dict:
    return json.loads((FIXTURE_DIR / "finding_log_page2.json").read_text())


@pytest.fixture
def auth_status_ok() -> dict:
    return json.loads((FIXTURE_DIR / "auth_status_ok.json").read_text())


@pytest.fixture
def tmp_output_dir(tmp_path) -> Path:
    out = tmp_path / "output"
    out.mkdir()
    return out
```

- [ ] **Step 6: Verify fixtures load**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest --collect-only
```

Expected: `0 tests collected` (no test files yet) but no errors loading conftest.

- [ ] **Step 7: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/tests/
git commit -m "test(endor-reports): add fixture data for FindingLog + auth status"
```

---

## Task 3: Filter template renderer (`lib/filter_template.py`)

Mustache-style template engine — supports `{{var}}` substitution and `{{#if var}}...{{/if}}` conditional blocks. Deliberately limited (no nested ifs, no loops, no helpers) — anything more complex belongs in source-YAML pre-processing, not the template language.

**Files:**
- Create: `skills/endor-reports/tests/test_filter_template.py`
- Create: `skills/endor-reports/lib/filter_template.py`

- [ ] **Step 1: Write the failing tests**

File: `skills/endor-reports/tests/test_filter_template.py`

```python
"""Tests for the Mustache-style filter template renderer."""
from __future__ import annotations

import pytest

from lib.filter_template import render, TemplateError


class TestSimpleVarSubstitution:
    def test_single_var(self):
        assert render("hello {{name}}", {"name": "world"}) == "hello world"

    def test_multiple_vars(self):
        assert render("{{a}}-{{b}}", {"a": "x", "b": "y"}) == "x-y"

    def test_repeated_var(self):
        assert render("{{x}} and {{x}}", {"x": "z"}) == "z and z"

    def test_no_vars(self):
        assert render("plain text", {}) == "plain text"

    def test_var_with_spaces_inside_braces_is_trimmed(self):
        assert render("{{ name }}", {"name": "x"}) == "x"

    def test_missing_var_raises(self):
        with pytest.raises(TemplateError, match="undefined variable: name"):
            render("hello {{name}}", {})


class TestConditionalBlocks:
    def test_truthy_value_renders_block(self):
        tpl = "a {{#if x}}b {{x}} c{{/if}} d"
        assert render(tpl, {"x": "MID"}) == "a b MID c d"

    def test_falsy_value_skips_block(self):
        tpl = "a {{#if x}}b{{/if}} c"
        assert render(tpl, {"x": None}) == "a  c"

    def test_missing_var_in_if_skips_block(self):
        tpl = "a {{#if x}}b{{/if}} c"
        assert render(tpl, {}) == "a  c"

    def test_empty_string_is_falsy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": ""}) == ""

    def test_zero_is_falsy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": 0}) == ""

    def test_false_is_falsy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": False}) == ""

    def test_nonempty_string_is_truthy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": "anything"}) == "YES"


class TestRealisticEndorFilterTemplate:
    def test_remediation_filter(self):
        tpl = (
            'spec.operation == "OPERATION_DELETE"\n'
            'and meta.update_time >= "{{start_date}}"\n'
            'and meta.update_time <= "{{end_date}}"\n'
            '{{#if project_uuid}}and spec.project_uuid == "{{project_uuid}}"{{/if}}'
        )
        params = {
            "start_date": "2026-04-01",
            "end_date": "2026-04-30",
            "project_uuid": "abc123abc123abc123abc123",
        }
        out = render(tpl, params)
        assert 'meta.update_time >= "2026-04-01"' in out
        assert 'meta.update_time <= "2026-04-30"' in out
        assert 'spec.project_uuid == "abc123abc123abc123abc123"' in out

    def test_remediation_filter_without_optional_project(self):
        tpl = (
            'meta.update_time >= "{{start_date}}"\n'
            '{{#if project_uuid}}and spec.project_uuid == "{{project_uuid}}"{{/if}}'
        )
        params = {"start_date": "2026-04-01", "project_uuid": None}
        out = render(tpl, params)
        assert 'meta.update_time >= "2026-04-01"' in out
        assert "project_uuid" not in out
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_filter_template.py -v
```

Expected: `ModuleNotFoundError: No module named 'lib.filter_template'`.

- [ ] **Step 3: Write the implementation**

File: `skills/endor-reports/lib/filter_template.py`

```python
"""Mustache-style filter template renderer.

Supports:
  - {{var}}                 — variable substitution; missing vars raise TemplateError.
  - {{#if var}}...{{/if}}   — conditional block; renders body iff var is truthy AND defined.

Deliberately limited: no nested conditionals, no loops, no helpers. If a source's
filter needs more complexity, it should pre-compute values in Python before calling render().
"""
from __future__ import annotations

import re
from typing import Any, Mapping


class TemplateError(ValueError):
    pass


_IF_BLOCK_RE = re.compile(r"\{\{#if\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}(.*?)\{\{/if\}\}", re.DOTALL)
_VAR_RE = re.compile(r"\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}")


def render(template: str, params: Mapping[str, Any]) -> str:
    """Render a Mustache-style template string against the provided params.

    Raises TemplateError if a {{var}} reference is missing from params (outside an {{#if}} block).
    Inside {{#if var}}...{{/if}}, a missing or falsy var causes the block to be skipped silently.
    """
    # Pass 1: process {{#if var}}...{{/if}} blocks.
    def _resolve_if(match: re.Match) -> str:
        var_name = match.group(1)
        body = match.group(2)
        value = params.get(var_name)
        if not value:
            return ""
        return body

    rendered = _IF_BLOCK_RE.sub(_resolve_if, template)

    # Pass 2: substitute remaining {{var}} references; missing → error.
    def _resolve_var(match: re.Match) -> str:
        var_name = match.group(1)
        if var_name not in params:
            raise TemplateError(f"undefined variable: {var_name}")
        return str(params[var_name])

    return _VAR_RE.sub(_resolve_var, rendered)
```

- [ ] **Step 4: Run the tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_filter_template.py -v
```

Expected: all 14 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/lib/filter_template.py skills/endor-reports/tests/test_filter_template.py
git commit -m "feat(endor-reports): add Mustache-style filter template renderer"
```

---

## Task 4: Output path resolver (`lib/output.py`)

Resolves the destination CSV path. Three rules, in order: explicit `--output PATH`, then `--output-dir DIR` with auto-named file, then fallback to `~/.claude/endor-reports/output/`.

**Files:**
- Create: `skills/endor-reports/tests/test_output.py`
- Create: `skills/endor-reports/lib/output.py`

- [ ] **Step 1: Write the failing tests**

File: `skills/endor-reports/tests/test_output.py`

```python
"""Tests for output path resolution."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from lib.output import resolve_output_path


class TestExplicitOutput:
    def test_explicit_path_used_verbatim(self, tmp_path):
        explicit = tmp_path / "my-report.csv"
        result = resolve_output_path(
            source_name="remediation",
            explicit=str(explicit),
            output_dir=None,
            fallback_dir=tmp_path / "fallback",
            now_utc="20260429_120000",
        )
        assert result == explicit


class TestOutputDir:
    def test_output_dir_auto_names(self, tmp_path):
        result = resolve_output_path(
            source_name="remediation",
            explicit=None,
            output_dir=str(tmp_path),
            fallback_dir=tmp_path / "ignored",
            now_utc="20260429_120000",
        )
        assert result == tmp_path / "remediation_20260429_120000.csv"

    def test_output_dir_creates_missing(self, tmp_path):
        target_dir = tmp_path / "new-dir"
        assert not target_dir.exists()
        result = resolve_output_path(
            source_name="remediation",
            explicit=None,
            output_dir=str(target_dir),
            fallback_dir=tmp_path / "ignored",
            now_utc="20260429_120000",
        )
        assert target_dir.exists()
        assert result.parent == target_dir


class TestFallback:
    def test_fallback_when_neither_provided(self, tmp_path):
        fallback = tmp_path / "fallback"
        result = resolve_output_path(
            source_name="remediation",
            explicit=None,
            output_dir=None,
            fallback_dir=fallback,
            now_utc="20260429_120000",
        )
        assert result.parent == fallback
        assert fallback.exists()
        assert result.name == "remediation_20260429_120000.csv"


class TestTimestampFormat:
    def test_timestamp_when_not_provided_is_utc_yyyymmdd_hhmmss(self, tmp_path):
        result = resolve_output_path(
            source_name="remediation",
            explicit=None,
            output_dir=str(tmp_path),
            fallback_dir=tmp_path,
            now_utc=None,  # let it default
        )
        m = re.search(r"remediation_(\d{8}_\d{6})\.csv$", result.name)
        assert m is not None, f"unexpected filename: {result.name}"
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_output.py -v
```

Expected: `ModuleNotFoundError: No module named 'lib.output'`.

- [ ] **Step 3: Write the implementation**

File: `skills/endor-reports/lib/output.py`

```python
"""Resolve output path for a report.

Resolution order (low → high specificity):
  1. fallback_dir / <source>_<timestamp>.csv   (used when nothing else provided)
  2. <output_dir> / <source>_<timestamp>.csv
  3. <explicit_path>                            (verbatim)
"""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def resolve_output_path(
    source_name: str,
    explicit: Optional[str],
    output_dir: Optional[str],
    fallback_dir: Path,
    now_utc: Optional[str] = None,
    extension: str = "csv",
) -> Path:
    """Return the resolved output Path, creating parent directories as needed."""
    if explicit:
        path = Path(explicit).expanduser().resolve()
        path.parent.mkdir(parents=True, exist_ok=True)
        return path

    timestamp = now_utc or _utc_timestamp()
    filename = f"{source_name}_{timestamp}.{extension}"

    if output_dir:
        directory = Path(output_dir).expanduser().resolve()
    else:
        directory = Path(fallback_dir).expanduser().resolve()

    directory.mkdir(parents=True, exist_ok=True)
    return directory / filename
```

- [ ] **Step 4: Run the tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_output.py -v
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/lib/output.py skills/endor-reports/tests/test_output.py
git commit -m "feat(endor-reports): add output path resolver"
```

---

## Task 5: Source loader (`lib/source_loader.py`)

Load a source YAML into a typed dataclass. v0.5 only needs the common header + `api_list` block; `api_job` field is parsed-but-ignored (set to None) to avoid load errors.

**Files:**
- Create: `skills/endor-reports/tests/test_source_loader.py`
- Create: `skills/endor-reports/lib/source_loader.py`

- [ ] **Step 1: Write the failing tests**

File: `skills/endor-reports/tests/test_source_loader.py`

```python
"""Tests for source YAML loading."""
from __future__ import annotations

import textwrap
from pathlib import Path

import pytest

from lib.source_loader import load_source, SourceLoadError, ApiListConfig, Column, Parameter


def _write(tmp_path: Path, name: str, body: str) -> Path:
    path = tmp_path / f"{name}.yaml"
    path.write_text(textwrap.dedent(body).lstrip())
    return path


class TestMinimalApiListSource:
    def test_loads_minimal_source(self, tmp_path):
        path = _write(tmp_path, "remediation", """
            name: remediation
            description: Remediated findings within a date range
            modes: [api_list]
            default_mode: api_list
            default_format: [csv]
            parameters:
              - { name: start_date, type: date, required: true }
              - { name: end_date,   type: date, required: true }
              - { name: project_uuid, type: string, required: false }
            api_list:
              resource: FindingLog
              filter_template: |
                spec.operation == "OPERATION_DELETE"
                and meta.update_time >= "{{start_date}}"
              fetched_fields:
                - meta.name
                - spec.vulnerability.cve_id
              default_columns:
                - { header: "CVE ID", source: spec.vulnerability.cve_id, fallback: missing }
                - { header: "Resolved At", source: meta.update_time }
              pagination:
                page_size: 500
        """)

        src = load_source(path)
        assert src.name == "remediation"
        assert src.description.startswith("Remediated")
        assert src.modes == ["api_list"]
        assert src.default_mode == "api_list"
        assert src.default_format == ["csv"]
        assert len(src.parameters) == 3
        assert src.parameters[0] == Parameter(name="start_date", type="date", required=True, default=None)
        assert src.parameters[2].required is False
        assert isinstance(src.api_list, ApiListConfig)
        assert src.api_list.resource == "FindingLog"
        assert "OPERATION_DELETE" in src.api_list.filter_template
        assert src.api_list.fetched_fields == ["meta.name", "spec.vulnerability.cve_id"]
        assert len(src.api_list.default_columns) == 2
        assert src.api_list.default_columns[0] == Column(header="CVE ID", source="spec.vulnerability.cve_id", fallback="missing", format=None)
        assert src.api_list.default_columns[1].fallback == ""
        assert src.api_list.pagination_page_size == 500
        assert src.api_job is None


class TestErrors:
    def test_missing_name_raises(self, tmp_path):
        path = _write(tmp_path, "x", """
            description: foo
            modes: [api_list]
            default_mode: api_list
            api_list:
              resource: Finding
              filter_template: ""
              fetched_fields: []
              default_columns: []
        """)
        with pytest.raises(SourceLoadError, match="missing required key: name"):
            load_source(path)

    def test_unknown_mode_raises(self, tmp_path):
        path = _write(tmp_path, "x", """
            name: x
            description: y
            modes: [api_dance]
            default_mode: api_list
            api_list:
              resource: Finding
              filter_template: ""
              fetched_fields: []
              default_columns: []
        """)
        with pytest.raises(SourceLoadError, match="invalid mode"):
            load_source(path)

    def test_default_mode_not_in_modes_raises(self, tmp_path):
        path = _write(tmp_path, "x", """
            name: x
            description: y
            modes: [api_list]
            default_mode: api_job
            api_list:
              resource: Finding
              filter_template: ""
              fetched_fields: []
              default_columns: []
        """)
        with pytest.raises(SourceLoadError, match="default_mode .* not in modes"):
            load_source(path)

    def test_api_list_block_required_when_in_modes(self, tmp_path):
        path = _write(tmp_path, "x", """
            name: x
            description: y
            modes: [api_list]
            default_mode: api_list
        """)
        with pytest.raises(SourceLoadError, match="api_list block missing"):
            load_source(path)
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_source_loader.py -v
```

Expected: `ModuleNotFoundError: No module named 'lib.source_loader'`.

- [ ] **Step 3: Write the implementation**

File: `skills/endor-reports/lib/source_loader.py`

```python
"""Load and validate source YAML files into typed dataclasses.

v0.5 supports the common header + the api_list block. The api_job block is
parsed-but-stored-as-None so v1 can extend without schema breakage.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, List, Mapping, Optional

import yaml


class SourceLoadError(ValueError):
    pass


VALID_MODES = {"api_list", "api_job"}


@dataclass(frozen=True)
class Parameter:
    name: str
    type: str
    required: bool
    default: Any = None


@dataclass(frozen=True)
class Column:
    header: str
    source: str
    fallback: str = ""
    format: Optional[str] = None


@dataclass(frozen=True)
class ApiListConfig:
    resource: str
    filter_template: str
    fetched_fields: List[str]
    default_columns: List[Column]
    pagination_page_size: int = 500


@dataclass(frozen=True)
class Source:
    name: str
    description: str
    modes: List[str]
    default_mode: str
    default_format: List[str]
    parameters: List[Parameter]
    api_list: Optional[ApiListConfig]
    api_job: Optional[dict]  # opaque in v0.5


def _require(d: Mapping[str, Any], key: str, ctx: str = "source") -> Any:
    if key not in d:
        raise SourceLoadError(f"{ctx}: missing required key: {key}")
    return d[key]


def _parse_parameter(d: Mapping[str, Any]) -> Parameter:
    name = _require(d, "name", ctx="parameter")
    return Parameter(
        name=name,
        type=d.get("type", "string"),
        required=bool(d.get("required", False)),
        default=d.get("default"),
    )


def _parse_column(d: Mapping[str, Any]) -> Column:
    return Column(
        header=_require(d, "header", ctx="column"),
        source=_require(d, "source", ctx="column"),
        fallback=str(d.get("fallback", "")),
        format=d.get("format"),
    )


def _parse_api_list(d: Mapping[str, Any]) -> ApiListConfig:
    pagination = d.get("pagination") or {}
    return ApiListConfig(
        resource=_require(d, "resource", ctx="api_list"),
        filter_template=_require(d, "filter_template", ctx="api_list"),
        fetched_fields=list(d.get("fetched_fields", [])),
        default_columns=[_parse_column(c) for c in d.get("default_columns", [])],
        pagination_page_size=int(pagination.get("page_size", 500)),
    )


def load_source(path: Path) -> Source:
    """Load a source YAML file and return a validated Source dataclass."""
    raw = yaml.safe_load(Path(path).read_text())
    if not isinstance(raw, dict):
        raise SourceLoadError(f"{path}: file must contain a YAML mapping at the top level")

    name = _require(raw, "name")
    description = raw.get("description", "")
    modes = list(raw.get("modes", []))
    if not modes:
        raise SourceLoadError(f"{path}: at least one mode required in `modes`")
    for m in modes:
        if m not in VALID_MODES:
            raise SourceLoadError(f"{path}: invalid mode: {m}; valid: {sorted(VALID_MODES)}")
    default_mode = raw.get("default_mode", modes[0])
    if default_mode not in modes:
        raise SourceLoadError(f"{path}: default_mode `{default_mode}` not in modes {modes}")

    default_format = list(raw.get("default_format", ["csv"]))
    parameters = [_parse_parameter(p) for p in raw.get("parameters", [])]

    api_list = None
    if "api_list" in modes:
        if "api_list" not in raw:
            raise SourceLoadError(f"{path}: api_list block missing but listed in modes")
        api_list = _parse_api_list(raw["api_list"])

    api_job = raw.get("api_job")  # opaque

    return Source(
        name=name,
        description=description,
        modes=modes,
        default_mode=default_mode,
        default_format=default_format,
        parameters=parameters,
        api_list=api_list,
        api_job=api_job,
    )
```

- [ ] **Step 4: Run the tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_source_loader.py -v
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/lib/source_loader.py skills/endor-reports/tests/test_source_loader.py
git commit -m "feat(endor-reports): add source YAML loader with dataclass model"
```

---

## Task 6: Projection module (`lib/projection.py`)

Apply a list of `Column` objects to raw records (dicts), producing rows of column-header → value strings. Supports nested-path lookup (`spec.vulnerability.cve_id`), fallback when value is missing/empty, and a small set of named formatters.

**Files:**
- Create: `skills/endor-reports/tests/test_projection.py`
- Create: `skills/endor-reports/lib/projection.py`

- [ ] **Step 1: Write the failing tests**

File: `skills/endor-reports/tests/test_projection.py`

```python
"""Tests for the column projection module."""
from __future__ import annotations

import pytest

from lib.projection import project_record, project_records, lookup_path
from lib.source_loader import Column


class TestPathLookup:
    def test_top_level(self):
        assert lookup_path({"a": 1}, "a") == 1

    def test_nested(self):
        assert lookup_path({"a": {"b": {"c": "deep"}}}, "a.b.c") == "deep"

    def test_missing_returns_none(self):
        assert lookup_path({"a": 1}, "b") is None

    def test_partial_missing_returns_none(self):
        assert lookup_path({"a": {}}, "a.b.c") is None

    def test_traversing_non_dict_returns_none(self):
        assert lookup_path({"a": "string"}, "a.b") is None


class TestProjectRecord:
    def test_simple_projection(self):
        record = {"meta": {"name": "x"}, "spec": {"value": 42}}
        cols = [
            Column(header="Name", source="meta.name"),
            Column(header="Value", source="spec.value"),
        ]
        assert project_record(record, cols) == {"Name": "x", "Value": "42"}

    def test_missing_uses_fallback(self):
        record = {"meta": {}}
        cols = [Column(header="Name", source="meta.name", fallback="N/A")]
        assert project_record(record, cols) == {"Name": "N/A"}

    def test_empty_string_uses_fallback(self):
        record = {"x": ""}
        cols = [Column(header="X", source="x", fallback="missing")]
        assert project_record(record, cols) == {"X": "missing"}

    def test_zero_is_kept_not_treated_as_missing(self):
        record = {"x": 0}
        cols = [Column(header="X", source="x", fallback="missing")]
        assert project_record(record, cols) == {"X": "0"}

    def test_false_is_kept(self):
        record = {"x": False}
        cols = [Column(header="X", source="x", fallback="missing")]
        assert project_record(record, cols) == {"X": "False"}

    def test_list_value_serialized_as_pipe_joined(self):
        record = {"tags": ["a", "b", "c"]}
        cols = [Column(header="Tags", source="tags")]
        assert project_record(record, cols) == {"Tags": "a|b|c"}

    def test_empty_list_uses_fallback(self):
        record = {"tags": []}
        cols = [Column(header="Tags", source="tags", fallback="none")]
        assert project_record(record, cols) == {"Tags": "none"}


class TestProjectRecords:
    def test_multiple_records(self):
        records = [
            {"meta": {"name": "a"}},
            {"meta": {"name": "b"}},
        ]
        cols = [Column(header="Name", source="meta.name")]
        assert project_records(records, cols) == [{"Name": "a"}, {"Name": "b"}]

    def test_empty_input(self):
        assert project_records([], [Column(header="X", source="x")]) == []


class TestFormatters:
    def test_iso_date_formatter_strips_time(self):
        record = {"t": "2026-04-29T14:22:00Z"}
        cols = [Column(header="Date", source="t", format="iso_date")]
        assert project_record(record, cols) == {"Date": "2026-04-29"}

    def test_iso_date_passes_through_invalid(self):
        record = {"t": "not-a-date"}
        cols = [Column(header="Date", source="t", format="iso_date")]
        assert project_record(record, cols) == {"Date": "not-a-date"}

    def test_unknown_formatter_raises(self):
        record = {"t": "x"}
        cols = [Column(header="Date", source="t", format="bogus")]
        with pytest.raises(ValueError, match="unknown formatter: bogus"):
            project_record(record, cols)
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_projection.py -v
```

Expected: `ModuleNotFoundError: No module named 'lib.projection'`.

- [ ] **Step 3: Write the implementation**

File: `skills/endor-reports/lib/projection.py`

```python
"""Apply column projections to raw records.

A Column maps a dotted source path (e.g. "spec.vulnerability.cve_id") to a header.
When the looked-up value is None, an empty string, or an empty list, the column's
fallback is used. Lists are pipe-joined. Optional named formatters transform the
value before stringification.
"""
from __future__ import annotations

from typing import Any, Iterable, List, Mapping

from lib.source_loader import Column


def lookup_path(record: Mapping[str, Any], path: str) -> Any:
    """Walk a dotted path through nested mappings; return None on miss."""
    cursor: Any = record
    for part in path.split("."):
        if not isinstance(cursor, Mapping) or part not in cursor:
            return None
        cursor = cursor[part]
    return cursor


def _is_missing(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, (str, list, tuple)) and len(value) == 0:
        return True
    return False


def _apply_formatter(value: Any, formatter: str) -> str:
    if formatter == "iso_date":
        if not isinstance(value, str):
            return str(value)
        # ISO 8601 timestamps look like "2026-04-29T14:22:00Z" → keep the date prefix.
        return value.split("T", 1)[0] if "T" in value else value
    raise ValueError(f"unknown formatter: {formatter}")


def _stringify(value: Any) -> str:
    if isinstance(value, list):
        return "|".join(str(v) for v in value)
    return str(value)


def project_record(record: Mapping[str, Any], columns: Iterable[Column]) -> dict:
    out: dict = {}
    for col in columns:
        raw = lookup_path(record, col.source)
        if _is_missing(raw):
            out[col.header] = col.fallback
            continue
        if col.format:
            out[col.header] = _apply_formatter(raw, col.format)
        else:
            out[col.header] = _stringify(raw)
    return out


def project_records(records: Iterable[Mapping[str, Any]], columns: List[Column]) -> List[dict]:
    return [project_record(r, columns) for r in records]
```

- [ ] **Step 4: Run the tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_projection.py -v
```

Expected: all 14 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/lib/projection.py skills/endor-reports/tests/test_projection.py
git commit -m "feat(endor-reports): add column projection with nested-path lookup"
```

---

## Task 7: endorctl client — auth probe (`lib/endorctl_client.py`, part 1)

The auth probe wraps `endorctl auth status --json` (with a fallback for older `endorctl` versions that lack the `--json` flag). Returns one of three states: OK, NOT_AUTHED, NAMESPACE_AMBIGUOUS. Subprocess invocation is isolated behind a single `_run_endorctl` helper so tests can monkeypatch it.

**Files:**
- Create: `skills/endor-reports/tests/test_endorctl_client.py`
- Create: `skills/endor-reports/lib/endorctl_client.py`

- [ ] **Step 1: Write the failing tests for auth**

File: `skills/endor-reports/tests/test_endorctl_client.py`

```python
"""Tests for the endorctl subprocess client (auth probe + paginated list)."""
from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import List

import pytest

from lib import endorctl_client as ec
from lib.endorctl_client import AuthStatus


@dataclass
class FakeRun:
    """Container for a single mocked subprocess call result."""
    stdout: str = ""
    stderr: str = ""
    returncode: int = 0


class FakeRunner:
    """Records calls; returns queued FakeRun results in order."""

    def __init__(self, results: List[FakeRun]):
        self.results = list(results)
        self.calls: List[List[str]] = []

    def __call__(self, cmd, capture_output=True, text=True, timeout=None, check=False):
        self.calls.append(list(cmd))
        if not self.results:
            raise AssertionError(f"no more queued FakeRun for cmd: {cmd}")
        result = self.results.pop(0)
        return subprocess.CompletedProcess(
            args=cmd, returncode=result.returncode, stdout=result.stdout, stderr=result.stderr
        )


@pytest.fixture
def patch_runner(monkeypatch):
    def _install(results):
        runner = FakeRunner(results)
        monkeypatch.setattr(ec, "_run_endorctl", runner)
        return runner
    return _install


class TestAuthOk:
    def test_returns_ok_with_namespace(self, patch_runner, auth_status_ok):
        runner = patch_runner([FakeRun(stdout=json.dumps(auth_status_ok), returncode=0)])
        result = ec.check_auth()
        assert result.status == AuthStatus.OK
        assert result.namespace == "acme-tenant"
        assert runner.calls[0][:3] == ["endorctl", "auth", "status"]
        assert "--json" in runner.calls[0]

    def test_explicit_namespace_overrides(self, patch_runner, auth_status_ok):
        patch_runner([FakeRun(stdout=json.dumps(auth_status_ok), returncode=0)])
        result = ec.check_auth(namespace="prod-tenant")
        assert result.status == AuthStatus.OK
        assert result.namespace == "prod-tenant"


class TestAuthNotAuthed:
    def test_nonzero_returncode_means_not_authed(self, patch_runner):
        patch_runner([FakeRun(stderr="not authenticated", returncode=1)])
        result = ec.check_auth()
        assert result.status == AuthStatus.NOT_AUTHED
        assert "not authenticated" in (result.message or "")


class TestAuthFallback:
    def test_falls_back_to_text_parse_when_json_unsupported(self, patch_runner):
        # First call: --json fails because flag is unknown (returncode 2).
        # Second call: plain `endorctl auth status` returns text output.
        runner = patch_runner([
            FakeRun(stderr="unknown flag: --json", returncode=2),
            FakeRun(stdout="user: lmoreno@endor.ai\nnamespace: acme-tenant\n", returncode=0),
        ])
        result = ec.check_auth()
        assert result.status == AuthStatus.OK
        assert result.namespace == "acme-tenant"
        assert len(runner.calls) == 2
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_endorctl_client.py -v
```

Expected: `ImportError` / `ModuleNotFoundError` for `lib.endorctl_client`.

- [ ] **Step 3: Write the auth-probe implementation**

File: `skills/endor-reports/lib/endorctl_client.py`

```python
"""Subprocess wrappers for endorctl. v0.5 covers `auth status` and `api list`."""
from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from enum import Enum
from typing import Iterator, List, Optional


class AuthStatus(Enum):
    OK = "ok"
    NOT_AUTHED = "not_authed"
    NAMESPACE_AMBIGUOUS = "namespace_ambiguous"


@dataclass
class AuthResult:
    status: AuthStatus
    namespace: Optional[str] = None
    message: Optional[str] = None


def _run_endorctl(cmd: List[str], capture_output=True, text=True, timeout=None, check=False) -> subprocess.CompletedProcess:
    """Single chokepoint for subprocess invocation. Tests monkeypatch this."""
    return subprocess.run(cmd, capture_output=capture_output, text=text, timeout=timeout, check=check)


def _parse_text_auth_status(stdout: str) -> Optional[str]:
    """Best-effort extract `namespace:` from non-JSON `endorctl auth status` output."""
    m = re.search(r"^namespace:\s*(\S+)", stdout, re.MULTILINE)
    return m.group(1) if m else None


def check_auth(namespace: Optional[str] = None) -> AuthResult:
    """Probe endorctl auth state. Returns AuthResult with status/namespace/message."""
    # Prefer JSON output where available.
    json_proc = _run_endorctl(["endorctl", "auth", "status", "--json"])
    if json_proc.returncode == 0 and json_proc.stdout.strip():
        try:
            data = json.loads(json_proc.stdout)
        except json.JSONDecodeError:
            data = None
        if isinstance(data, dict) and data.get("authenticated", True) is not False:
            ns = namespace or data.get("namespace")
            if not ns:
                return AuthResult(status=AuthStatus.NAMESPACE_AMBIGUOUS, message="no namespace resolved")
            return AuthResult(status=AuthStatus.OK, namespace=ns)
        if isinstance(data, dict) and data.get("authenticated") is False:
            return AuthResult(status=AuthStatus.NOT_AUTHED, message=data.get("error", "not authenticated"))

    # Fallback: try plain text form (older endorctl versions).
    if "unknown flag" in (json_proc.stderr or "") or json_proc.returncode != 0:
        text_proc = _run_endorctl(["endorctl", "auth", "status"])
        if text_proc.returncode != 0:
            return AuthResult(status=AuthStatus.NOT_AUTHED, message=(text_proc.stderr or "not authenticated").strip())
        ns = namespace or _parse_text_auth_status(text_proc.stdout)
        if not ns:
            return AuthResult(status=AuthStatus.NAMESPACE_AMBIGUOUS, message="no namespace resolved")
        return AuthResult(status=AuthStatus.OK, namespace=ns)

    return AuthResult(status=AuthStatus.NOT_AUTHED, message=(json_proc.stderr or "not authenticated").strip())
```

- [ ] **Step 4: Run the auth tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_endorctl_client.py -v -k "Auth"
```

Expected: all `Test*Auth*` tests PASS (4 tests).

- [ ] **Step 5: Commit auth probe**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/lib/endorctl_client.py skills/endor-reports/tests/test_endorctl_client.py
git commit -m "feat(endor-reports): add endorctl auth probe (api_list mode)"
```

---

## Task 8: endorctl client — paginated list (`lib/endorctl_client.py`, part 2)

Add a streaming `list_resource` generator that calls `endorctl api list -r <Resource>` with `--filter`, `--field-mask`, `--page-size`, `--namespace`, follows `next_page_id` until exhausted, and yields one record at a time.

**Files:**
- Modify: `skills/endor-reports/tests/test_endorctl_client.py` (add tests)
- Modify: `skills/endor-reports/lib/endorctl_client.py` (add list_resource)

- [ ] **Step 1: Append the failing tests for list_resource**

Append to `skills/endor-reports/tests/test_endorctl_client.py`:

```python
class TestListResource:
    def test_single_page_yields_all_records(self, patch_runner, finding_log_page2):
        # page2 fixture has no next_page_id → terminates.
        runner = patch_runner([FakeRun(stdout=json.dumps(finding_log_page2), returncode=0)])
        records = list(ec.list_resource(
            resource="FindingLog",
            filter_expr='spec.operation == "OPERATION_DELETE"',
            field_mask=["meta.name", "spec.vulnerability.cve_id"],
            namespace="acme-tenant",
            page_size=500,
        ))
        assert len(records) == 1
        assert records[0]["uuid"] == "fl-uuid-003"
        assert len(runner.calls) == 1
        cmd = runner.calls[0]
        assert cmd[:5] == ["endorctl", "api", "list", "-r", "FindingLog"]
        assert "--namespace" in cmd and "acme-tenant" in cmd
        assert "--filter" in cmd
        assert any('OPERATION_DELETE' in part for part in cmd)
        assert "--page-size" in cmd and "500" in cmd
        assert "--field-mask" in cmd

    def test_multi_page_follows_next_page_id(self, patch_runner, finding_log_page1, finding_log_page2):
        runner = patch_runner([
            FakeRun(stdout=json.dumps(finding_log_page1), returncode=0),
            FakeRun(stdout=json.dumps(finding_log_page2), returncode=0),
        ])
        records = list(ec.list_resource(
            resource="FindingLog",
            filter_expr='spec.operation == "OPERATION_DELETE"',
            field_mask=["meta.name"],
            namespace="acme-tenant",
            page_size=500,
        ))
        assert [r["uuid"] for r in records] == ["fl-uuid-001", "fl-uuid-002", "fl-uuid-003"]
        assert len(runner.calls) == 2
        # Second call must include the page token.
        assert "--page-token" in runner.calls[1]
        assert "PAGE2_TOKEN" in runner.calls[1]

    def test_nonzero_exit_raises(self, patch_runner):
        patch_runner([FakeRun(stderr="403 forbidden", returncode=1)])
        with pytest.raises(ec.EndorctlError, match="403 forbidden"):
            list(ec.list_resource(
                resource="FindingLog", filter_expr="x", field_mask=["a"],
                namespace="ns", page_size=10,
            ))

    def test_invalid_json_raises(self, patch_runner):
        patch_runner([FakeRun(stdout="not json", returncode=0)])
        with pytest.raises(ec.EndorctlError, match="failed to parse"):
            list(ec.list_resource(
                resource="FindingLog", filter_expr="x", field_mask=["a"],
                namespace="ns", page_size=10,
            ))
```

- [ ] **Step 2: Run the new tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_endorctl_client.py -v -k "ListResource"
```

Expected: `AttributeError: module 'lib.endorctl_client' has no attribute 'list_resource'` (or similar).

- [ ] **Step 3: Add `list_resource` and `EndorctlError`**

Append to `skills/endor-reports/lib/endorctl_client.py`:

```python
class EndorctlError(RuntimeError):
    pass


def list_resource(
    resource: str,
    filter_expr: str,
    field_mask: List[str],
    namespace: str,
    page_size: int = 500,
) -> Iterator[dict]:
    """Stream records from `endorctl api list -r <Resource>`, following pagination.

    Yields one record (dict) at a time. Raises EndorctlError on non-zero exit
    or unparseable JSON.
    """
    next_token: Optional[str] = None
    while True:
        cmd = [
            "endorctl", "api", "list",
            "-r", resource,
            "--namespace", namespace,
            "--filter", filter_expr,
            "--field-mask", ",".join(field_mask),
            "--page-size", str(page_size),
            "--output-format", "json",
        ]
        if next_token:
            cmd.extend(["--page-token", next_token])

        proc = _run_endorctl(cmd)
        if proc.returncode != 0:
            raise EndorctlError((proc.stderr or proc.stdout or "endorctl failed").strip())

        try:
            payload = json.loads(proc.stdout)
        except json.JSONDecodeError as e:
            raise EndorctlError(f"failed to parse endorctl JSON output: {e}") from e

        list_block = payload.get("list", {}) if isinstance(payload, dict) else {}
        objects = list_block.get("objects", [])
        for obj in objects:
            yield obj

        next_token = (list_block.get("response") or {}).get("next_page_id")
        if not next_token:
            break
```

- [ ] **Step 4: Run all client tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_endorctl_client.py -v
```

Expected: all 8 tests PASS.

- [ ] **Step 5: Commit list_resource**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/lib/endorctl_client.py skills/endor-reports/tests/test_endorctl_client.py
git commit -m "feat(endor-reports): add paginated endorctl api list streaming"
```

---

## Task 9: CSV renderer (`lib/renderers/csv.py`)

Stream-write rows to a CSV file. Header from the column list, RFC 4180 quoting, UTF-8, LF line endings. No PDF in v0.5.

**Files:**
- Create: `skills/endor-reports/tests/test_csv_renderer.py`
- Create: `skills/endor-reports/lib/renderers/csv.py`

- [ ] **Step 1: Write the failing tests**

File: `skills/endor-reports/tests/test_csv_renderer.py`

```python
"""Tests for the CSV renderer."""
from __future__ import annotations

from pathlib import Path

from lib.renderers.csv import write_csv


class TestWriteCsv:
    def test_basic_write(self, tmp_path):
        out = tmp_path / "out.csv"
        write_csv(
            path=out,
            headers=["A", "B"],
            rows=[{"A": "1", "B": "2"}, {"A": "3", "B": "4"}],
        )
        text = out.read_text(encoding="utf-8")
        assert text == "A,B\n1,2\n3,4\n"

    def test_quotes_values_with_commas(self, tmp_path):
        out = tmp_path / "out.csv"
        write_csv(
            path=out,
            headers=["Name"],
            rows=[{"Name": "Smith, Bob"}],
        )
        assert out.read_text(encoding="utf-8") == 'Name\n"Smith, Bob"\n'

    def test_escapes_embedded_quotes(self, tmp_path):
        out = tmp_path / "out.csv"
        write_csv(
            path=out,
            headers=["Note"],
            rows=[{"Note": 'He said "hi"'}],
        )
        assert out.read_text(encoding="utf-8") == 'Note\n"He said ""hi"""\n'

    def test_missing_header_in_row_writes_empty(self, tmp_path):
        out = tmp_path / "out.csv"
        write_csv(
            path=out,
            headers=["A", "B"],
            rows=[{"A": "1"}],  # B missing
        )
        assert out.read_text(encoding="utf-8") == "A,B\n1,\n"

    def test_empty_rows_writes_only_header(self, tmp_path):
        out = tmp_path / "out.csv"
        write_csv(path=out, headers=["A", "B"], rows=[])
        assert out.read_text(encoding="utf-8") == "A,B\n"

    def test_utf8_content_round_trips(self, tmp_path):
        out = tmp_path / "out.csv"
        write_csv(
            path=out,
            headers=["Ecosystem"],
            rows=[{"Ecosystem": "Python"}, {"Ecosystem": "Go"}, {"Ecosystem": "日本語"}],
        )
        assert "日本語" in out.read_text(encoding="utf-8")

    def test_returns_row_count(self, tmp_path):
        out = tmp_path / "out.csv"
        n = write_csv(path=out, headers=["A"], rows=[{"A": "x"}, {"A": "y"}, {"A": "z"}])
        assert n == 3
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_csv_renderer.py -v
```

Expected: `ModuleNotFoundError: No module named 'lib.renderers.csv'`.

- [ ] **Step 3: Write the implementation**

File: `skills/endor-reports/lib/renderers/csv.py`

```python
"""CSV renderer — RFC 4180 quoting, UTF-8, LF line endings, streaming write."""
from __future__ import annotations

import csv
from pathlib import Path
from typing import Iterable, List, Mapping


def write_csv(path: Path, headers: List[str], rows: Iterable[Mapping[str, str]]) -> int:
    """Write headers + rows to `path`. Returns the number of data rows written."""
    count = 0
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=headers,
            quoting=csv.QUOTE_MINIMAL,
            lineterminator="\n",
            extrasaction="ignore",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({h: row.get(h, "") for h in headers})
            count += 1
    return count
```

- [ ] **Step 4: Run the tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_csv_renderer.py -v
```

Expected: all 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/lib/renderers/csv.py skills/endor-reports/tests/test_csv_renderer.py
git commit -m "feat(endor-reports): add CSV renderer with RFC 4180 quoting"
```

---

## Task 10: First source — `sources/remediation.yaml`

Declares the v0.5 remediation report: remediated findings (`OPERATION_DELETE`) within a date range, optionally project-scoped. The column set mirrors what `generate_remediation_report` script emits, minus enrichments deferred to v1 (CVE lookup via GHSA, ecosystem label translation).

**Files:**
- Create: `skills/endor-reports/sources/remediation.yaml`
- Modify: `skills/endor-reports/tests/test_source_loader.py` (add a parsing test for the real file)

- [ ] **Step 1: Write the source file**

File: `skills/endor-reports/sources/remediation.yaml`

```yaml
name: remediation
description: Findings remediated (OPERATION_DELETE) within a date range
modes: [api_list]
default_mode: api_list
default_format: [csv]
parameters:
  - { name: start_date, type: date, required: true }
  - { name: end_date,   type: date, required: true }
  - { name: project_uuid, type: string, required: false }
api_list:
  resource: FindingLog
  filter_template: |
    spec.operation == "OPERATION_DELETE"
    and meta.update_time >= "{{start_date}}T00:00:00Z"
    and meta.update_time <= "{{end_date}}T23:59:59Z"
    {{#if project_uuid}}and spec.project_uuid == "{{project_uuid}}"{{/if}}
  fetched_fields:
    - uuid
    - meta.name
    - meta.update_time
    - meta.create_time
    - spec.finding_uuid
    - spec.project_uuid
    - spec.vulnerability.cve_id
    - spec.vulnerability.ghsa_id
    - spec.finding_summary
    - spec.finding_level
    - spec.finding_categories
    - spec.finding_tags
  default_columns:
    - { header: "Finding Log UUID", source: uuid }
    - { header: "Finding UUID",     source: spec.finding_uuid }
    - { header: "CVE ID",           source: spec.vulnerability.cve_id, fallback: missing }
    - { header: "GHSA ID",          source: spec.vulnerability.ghsa_id, fallback: "" }
    - { header: "Summary",          source: spec.finding_summary }
    - { header: "Severity",         source: spec.finding_level }
    - { header: "Resolved At",      source: meta.update_time, format: iso_date }
    - { header: "Introduced At",    source: meta.create_time, format: iso_date }
    - { header: "Project UUID",     source: spec.project_uuid }
    - { header: "Tags",             source: spec.finding_tags, fallback: "" }
  pagination:
    page_size: 500
```

- [ ] **Step 2: Add a test that loads the real source file**

Append to `skills/endor-reports/tests/test_source_loader.py`:

```python
class TestRealRemediationSource:
    def test_loads_shipped_remediation(self):
        from pathlib import Path
        path = Path(__file__).parent.parent / "sources" / "remediation.yaml"
        src = load_source(path)
        assert src.name == "remediation"
        assert src.api_list is not None
        assert src.api_list.resource == "FindingLog"
        assert src.api_list.pagination_page_size == 500
        # Ensure the column we care about is present and uses iso_date formatter.
        resolved_at = next(c for c in src.api_list.default_columns if c.header == "Resolved At")
        assert resolved_at.format == "iso_date"
        assert resolved_at.source == "meta.update_time"
        # Optional param marked correctly.
        proj = next(p for p in src.parameters if p.name == "project_uuid")
        assert proj.required is False
```

- [ ] **Step 3: Run the test, confirm it passes**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_source_loader.py::TestRealRemediationSource -v
```

Expected: PASS.

- [ ] **Step 4: Verify the filter template renders correctly with realistic params**

Add a quick smoke test by hand at the REPL or with `python -c` to confirm the YAML's `filter_template` renders without errors:

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/python -c "
from pathlib import Path
from lib.source_loader import load_source
from lib.filter_template import render

src = load_source(Path('sources/remediation.yaml'))
out = render(src.api_list.filter_template, {
    'start_date': '2026-04-01', 'end_date': '2026-04-30', 'project_uuid': 'uuid-123'
})
print(out)
"
```

Expected output (whitespace flexible):
```
spec.operation == "OPERATION_DELETE"
and meta.update_time >= "2026-04-01T00:00:00Z"
and meta.update_time <= "2026-04-30T23:59:59Z"
and spec.project_uuid == "uuid-123"
```

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/sources/remediation.yaml skills/endor-reports/tests/test_source_loader.py
git commit -m "feat(endor-reports): add remediation source YAML"
```

---

## Task 11: Runner CLI scaffold (`run.py`, part 1: argparse + dispatch)

Build the bare CLI entry point: argparse, `--list-sources` and `--show-source <name>` sub-commands (no pipeline yet), and the structure for the main report-generation path.

**Files:**
- Create: `skills/endor-reports/run.py`
- Create: `skills/endor-reports/tests/test_run_cli.py`

- [ ] **Step 1: Write the failing tests for the dispatch surface**

File: `skills/endor-reports/tests/test_run_cli.py`

```python
"""Tests for the run.py CLI dispatch surface (no pipeline yet)."""
from __future__ import annotations

import io
import sys
from pathlib import Path

import pytest

import run


SOURCES_DIR = Path(__file__).parent.parent / "sources"


class TestListSources:
    def test_list_sources_prints_known_sources(self, capsys):
        exit_code = run.main(["--list-sources"], sources_dir=SOURCES_DIR)
        captured = capsys.readouterr()
        assert exit_code == 0
        assert "remediation" in captured.out

    def test_list_sources_shows_description(self, capsys):
        run.main(["--list-sources"], sources_dir=SOURCES_DIR)
        captured = capsys.readouterr()
        assert "remediated" in captured.out.lower()


class TestShowSource:
    def test_show_source_prints_yaml(self, capsys):
        exit_code = run.main(["--show-source", "remediation"], sources_dir=SOURCES_DIR)
        captured = capsys.readouterr()
        assert exit_code == 0
        assert "FindingLog" in captured.out
        assert "filter_template" in captured.out

    def test_show_unknown_source_exits_1(self, capsys):
        exit_code = run.main(["--show-source", "nonexistent"], sources_dir=SOURCES_DIR)
        captured = capsys.readouterr()
        assert exit_code == 1
        assert "unknown source" in captured.err.lower() or "unknown source" in captured.out.lower()


class TestArgsValidation:
    def test_no_source_no_command_exits_with_usage(self, capsys):
        exit_code = run.main([], sources_dir=SOURCES_DIR)
        captured = capsys.readouterr()
        assert exit_code != 0

    def test_unknown_source_exits_1(self, capsys):
        exit_code = run.main(["nonexistent"], sources_dir=SOURCES_DIR)
        captured = capsys.readouterr()
        assert exit_code == 1
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_run_cli.py -v
```

Expected: `ModuleNotFoundError: No module named 'run'`.

- [ ] **Step 3: Write the runner scaffold**

File: `skills/endor-reports/run.py`

```python
"""endor-reports runner CLI.

Stable subprocess shape: `python skills/endor-reports/run.py <source> [flags]`.
v0.5 supports the api_list pipeline end-to-end; api_job, scheduling, recipes,
widen-on-miss, and PDF rendering are deferred to v1.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List, Optional, Sequence

from lib.source_loader import load_source, SourceLoadError, Source

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_SOURCES_DIR = SCRIPT_DIR / "sources"
DEFAULT_FALLBACK_OUTPUT = Path("~/.claude/endor-reports/output").expanduser()


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="run.py",
        description="Generate Endor Labs reports via endorctl.",
    )
    p.add_argument("source", nargs="?", help="Source name (see --list-sources)")
    p.add_argument("--list-sources", action="store_true", help="List available sources")
    p.add_argument("--show-source", metavar="NAME", help="Print the YAML of a source")
    p.add_argument("--since", metavar="YYYY-MM-DD", help="Maps to start_date parameter")
    p.add_argument("--until", metavar="YYYY-MM-DD", help="Maps to end_date parameter")
    p.add_argument("--param", action="append", default=[], metavar="KEY=VALUE",
                   help="Additional source parameters (repeatable)")
    p.add_argument("--namespace", help="Override endorctl namespace")
    p.add_argument("--output", help="Explicit output file path")
    p.add_argument("--output-dir", help="Output directory (file auto-named)")
    p.add_argument("--format", choices=["csv"], default="csv",
                   help="Output format (v0.5: csv only)")
    return p


def _list_sources(sources_dir: Path) -> int:
    files = sorted(sources_dir.glob("*.yaml"))
    if not files:
        print("(no sources found)")
        return 0
    for f in files:
        try:
            src = load_source(f)
            print(f"{src.name:<30} {src.description}")
        except SourceLoadError as e:
            print(f"{f.stem:<30} (load error: {e})", file=sys.stderr)
    return 0


def _show_source(name: str, sources_dir: Path) -> int:
    path = sources_dir / f"{name}.yaml"
    if not path.exists():
        print(f"unknown source: {name}", file=sys.stderr)
        return 1
    print(path.read_text())
    return 0


def _resolve_source_or_die(name: str, sources_dir: Path) -> Optional[Source]:
    path = sources_dir / f"{name}.yaml"
    if not path.exists():
        print(f"unknown source: {name}", file=sys.stderr)
        return None
    try:
        return load_source(path)
    except SourceLoadError as e:
        print(f"failed to load source `{name}`: {e}", file=sys.stderr)
        return None


def main(argv: Optional[Sequence[str]] = None, sources_dir: Optional[Path] = None) -> int:
    sources_dir = sources_dir or DEFAULT_SOURCES_DIR
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.list_sources:
        return _list_sources(sources_dir)

    if args.show_source:
        return _show_source(args.show_source, sources_dir)

    if not args.source:
        parser.print_usage(sys.stderr)
        return 2

    source = _resolve_source_or_die(args.source, sources_dir)
    if source is None:
        return 1

    # Pipeline integration is added in Task 12.
    print(f"(pipeline not implemented in this commit; loaded source `{source.name}`)")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
```

- [ ] **Step 4: Run the tests, confirm they pass**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_run_cli.py -v
```

Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/run.py skills/endor-reports/tests/test_run_cli.py
git commit -m "feat(endor-reports): add run.py CLI scaffold (--list-sources, --show-source)"
```

---

## Task 12: Runner pipeline integration (`run.py`, part 2)

Wire the full `api_list` pipeline into `run.py`: parameter resolution, auth pre-flight, filter render, paginated fetch, projection, CSV write. Errors emit human-readable messages and exit codes 1 (operational) or 2 (needs human input).

**Files:**
- Modify: `skills/endor-reports/run.py`
- Modify: `skills/endor-reports/tests/test_run_cli.py` (add pipeline tests with mocks)

- [ ] **Step 1: Append pipeline tests**

Append to `skills/endor-reports/tests/test_run_cli.py`:

```python
import json as _json
import subprocess as _subprocess

import lib.endorctl_client as ec_module


@pytest.fixture
def mock_endorctl(monkeypatch, finding_log_page1, finding_log_page2, auth_status_ok):
    """Mock _run_endorctl to handle auth + paginated list calls."""
    queue = [
        # auth status --json
        _json.dumps(auth_status_ok),
        # api list page 1
        _json.dumps(finding_log_page1),
        # api list page 2
        _json.dumps(finding_log_page2),
    ]
    calls = []

    def fake_run(cmd, capture_output=True, text=True, timeout=None, check=False):
        calls.append(list(cmd))
        if not queue:
            raise AssertionError(f"unexpected extra endorctl call: {cmd}")
        out = queue.pop(0)
        return _subprocess.CompletedProcess(args=cmd, returncode=0, stdout=out, stderr="")

    monkeypatch.setattr(ec_module, "_run_endorctl", fake_run)
    return calls


class TestPipelineHappyPath:
    def test_full_run_writes_csv(self, mock_endorctl, tmp_path, capsys):
        out_path = tmp_path / "remediation.csv"
        exit_code = run.main([
            "remediation",
            "--since", "2026-04-01",
            "--until", "2026-04-30",
            "--output", str(out_path),
        ], sources_dir=SOURCES_DIR)
        assert exit_code == 0
        assert out_path.exists()
        text = out_path.read_text()
        # Header + 3 data rows.
        assert text.count("\n") == 4
        assert "Finding Log UUID" in text
        assert "fl-uuid-001" in text
        assert "fl-uuid-002" in text
        assert "fl-uuid-003" in text
        # CVE ID column projection: row 2 was missing CVE → fallback "missing".
        rows = text.splitlines()
        assert "missing" in rows[2]  # second data row corresponds to fl-uuid-002

    def test_optional_project_param_threads_through_filter(self, mock_endorctl, tmp_path):
        out_path = tmp_path / "out.csv"
        run.main([
            "remediation",
            "--since", "2026-04-01",
            "--until", "2026-04-30",
            "--param", "project_uuid=abc123abc123abc123abc123",
            "--output", str(out_path),
        ], sources_dir=SOURCES_DIR)
        list_call = next(c for c in mock_endorctl if c[:3] == ["endorctl", "api", "list"])
        # Confirm the project filter clause made it into --filter.
        filter_idx = list_call.index("--filter")
        assert "abc123abc123abc123abc123" in list_call[filter_idx + 1]


class TestPipelineErrors:
    def test_missing_required_param_exits_2(self, mock_endorctl, tmp_path, capsys):
        # No --since / --until provided.
        exit_code = run.main([
            "remediation",
            "--output", str(tmp_path / "out.csv"),
        ], sources_dir=SOURCES_DIR)
        assert exit_code == 2
        captured = capsys.readouterr()
        assert "missing required parameter" in (captured.err + captured.out).lower()

    def test_auth_failure_exits_2_needs_auth(self, monkeypatch, tmp_path, capsys):
        def fake_run(cmd, capture_output=True, text=True, timeout=None, check=False):
            return _subprocess.CompletedProcess(
                args=cmd, returncode=1, stdout="", stderr="not authenticated. run endorctl init.",
            )
        monkeypatch.setattr(ec_module, "_run_endorctl", fake_run)
        exit_code = run.main([
            "remediation",
            "--since", "2026-04-01",
            "--until", "2026-04-30",
        ], sources_dir=SOURCES_DIR)
        assert exit_code == 2
        captured = capsys.readouterr()
        combined = (captured.err + captured.out).lower()
        assert "endorctl init" in combined or "not authenticated" in combined
```

- [ ] **Step 2: Run the new tests, confirm they fail**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_run_cli.py -v -k "Pipeline"
```

Expected: tests fail because `run.py` still prints the placeholder message.

- [ ] **Step 3: Replace the placeholder pipeline with the real implementation**

Edit `skills/endor-reports/run.py`. Replace the placeholder block at the end of `main()` with the full pipeline. The full file becomes:

```python
"""endor-reports runner CLI.

Stable subprocess shape: `python skills/endor-reports/run.py <source> [flags]`.
v0.5 supports the api_list pipeline end-to-end; api_job, scheduling, recipes,
widen-on-miss, and PDF rendering are deferred to v1.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence

from lib.endorctl_client import AuthStatus, EndorctlError, check_auth, list_resource
from lib.filter_template import TemplateError, render
from lib.output import resolve_output_path
from lib.projection import project_records
from lib.renderers.csv import write_csv
from lib.source_loader import Source, SourceLoadError, load_source

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_SOURCES_DIR = SCRIPT_DIR / "sources"
DEFAULT_FALLBACK_OUTPUT = Path("~/.claude/endor-reports/output").expanduser()


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="run.py",
        description="Generate Endor Labs reports via endorctl.",
    )
    p.add_argument("source", nargs="?", help="Source name (see --list-sources)")
    p.add_argument("--list-sources", action="store_true", help="List available sources")
    p.add_argument("--show-source", metavar="NAME", help="Print the YAML of a source")
    p.add_argument("--since", metavar="YYYY-MM-DD", help="Maps to start_date parameter")
    p.add_argument("--until", metavar="YYYY-MM-DD", help="Maps to end_date parameter")
    p.add_argument("--param", action="append", default=[], metavar="KEY=VALUE",
                   help="Additional source parameters (repeatable)")
    p.add_argument("--namespace", help="Override endorctl namespace")
    p.add_argument("--output", help="Explicit output file path")
    p.add_argument("--output-dir", help="Output directory (file auto-named)")
    p.add_argument("--format", choices=["csv"], default="csv",
                   help="Output format (v0.5: csv only)")
    return p


def _list_sources(sources_dir: Path) -> int:
    files = sorted(sources_dir.glob("*.yaml"))
    if not files:
        print("(no sources found)")
        return 0
    for f in files:
        try:
            src = load_source(f)
            print(f"{src.name:<30} {src.description}")
        except SourceLoadError as e:
            print(f"{f.stem:<30} (load error: {e})", file=sys.stderr)
    return 0


def _show_source(name: str, sources_dir: Path) -> int:
    path = sources_dir / f"{name}.yaml"
    if not path.exists():
        print(f"unknown source: {name}", file=sys.stderr)
        return 1
    print(path.read_text())
    return 0


def _resolve_source_or_die(name: str, sources_dir: Path) -> Optional[Source]:
    path = sources_dir / f"{name}.yaml"
    if not path.exists():
        print(f"unknown source: {name}", file=sys.stderr)
        return None
    try:
        return load_source(path)
    except SourceLoadError as e:
        print(f"failed to load source `{name}`: {e}", file=sys.stderr)
        return None


def _resolve_params(source: Source, args: argparse.Namespace) -> Dict[str, object]:
    """Combine --since/--until shortcuts and --param key=value pairs, validate against source.parameters."""
    params: Dict[str, object] = {}
    # Defaults from source.
    for p in source.parameters:
        if p.default is not None:
            params[p.name] = p.default
    # --since / --until shortcuts.
    if args.since:
        params["start_date"] = args.since
    if args.until:
        params["end_date"] = args.until
    # --param key=value (repeatable).
    for raw in args.param:
        if "=" not in raw:
            raise ValueError(f"--param requires KEY=VALUE form, got: {raw}")
        k, v = raw.split("=", 1)
        params[k.strip()] = v.strip()
    # Ensure every defined parameter has a value (None for optional + unset).
    for p in source.parameters:
        if p.name not in params:
            params[p.name] = None
    # Required-param check.
    missing = [p.name for p in source.parameters if p.required and not params.get(p.name)]
    if missing:
        raise ValueError(f"missing required parameter(s): {', '.join(missing)}")
    return params


def _run_api_list(source: Source, params: Dict[str, object], args: argparse.Namespace) -> int:
    if source.api_list is None:
        print(f"source `{source.name}` has no api_list block", file=sys.stderr)
        return 1

    # Auth pre-flight.
    auth = check_auth(namespace=args.namespace)
    if auth.status == AuthStatus.NOT_AUTHED:
        print(f"needs_auth: {auth.message}\nRun `endorctl init` and re-invoke.", file=sys.stderr)
        return 2
    if auth.status == AuthStatus.NAMESPACE_AMBIGUOUS:
        print("needs_namespace: namespace could not be resolved. Pass --namespace.", file=sys.stderr)
        return 2

    # Render filter.
    try:
        filter_expr = render(source.api_list.filter_template, params)
    except TemplateError as e:
        print(f"filter template error: {e}", file=sys.stderr)
        return 1

    # Fetch.
    try:
        records = list(list_resource(
            resource=source.api_list.resource,
            filter_expr=filter_expr,
            field_mask=source.api_list.fetched_fields,
            namespace=auth.namespace,
            page_size=source.api_list.pagination_page_size,
        ))
    except EndorctlError as e:
        print(f"endorctl error: {e}", file=sys.stderr)
        return 1

    # Project + write.
    rows = project_records(records, source.api_list.default_columns)
    headers = [c.header for c in source.api_list.default_columns]
    out_path = resolve_output_path(
        source_name=source.name,
        explicit=args.output,
        output_dir=args.output_dir,
        fallback_dir=DEFAULT_FALLBACK_OUTPUT,
    )
    n = write_csv(path=out_path, headers=headers, rows=rows)
    print(f"wrote {n} rows to {out_path}")
    return 0


def main(argv: Optional[Sequence[str]] = None, sources_dir: Optional[Path] = None) -> int:
    sources_dir = sources_dir or DEFAULT_SOURCES_DIR
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.list_sources:
        return _list_sources(sources_dir)

    if args.show_source:
        return _show_source(args.show_source, sources_dir)

    if not args.source:
        parser.print_usage(sys.stderr)
        return 2

    source = _resolve_source_or_die(args.source, sources_dir)
    if source is None:
        return 1

    try:
        params = _resolve_params(source, args)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 2

    return _run_api_list(source, params, args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
```

- [ ] **Step 4: Run all tests, confirm everything passes**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest -v
```

Expected: all tests across all files PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/run.py skills/endor-reports/tests/test_run_cli.py
git commit -m "feat(endor-reports): wire api_list pipeline end-to-end in run.py"
```

---

## Task 13: SKILL.md (Claude-facing instructions)

Minimum-viable SKILL.md for v0.5: frontmatter with the tightened allowlist, a short body that teaches Claude what the skill does, the override translation table for the one supported source, and the two error protocols (`needs_auth`, `needs_namespace`). Other protocols (`needs_widening`, `unavailable_in_mode`) are referenced but flagged as v1.

**Files:**
- Create: `skills/endor-reports/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

File: `skills/endor-reports/SKILL.md`

```markdown
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

## When to use

The user asks for any of:

- "remediation report", "fixed findings", "what got resolved last month"
- "monthly Endor report" / "Endor CSV" / "export Endor findings"
- "list of remediated CVEs"

## Available sources (v0.5)

Run `python skills/endor-reports/run.py --list-sources` to see the live list. Today: `remediation` only.

## Invocation pattern

Always invoke through the runner — never write Python or call `endorctl api list` directly:

```bash
python skills/endor-reports/run.py <source> [flags]
```

### Translating user intent to flags

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
- **2** — needs human input. Two cases in v0.5:
  - **`needs_auth`** — runner stderr will mention "not authenticated" or "Run `endorctl init`". Ask the user: *"You need to authenticate with endorctl first. Want me to run `endorctl init`?"* On yes, run `endorctl init` (this opens a browser), wait for the user to confirm completion, then re-invoke `run.py` with the same flags.
  - **`needs_namespace`** — multiple namespaces resolvable. Ask the user which namespace to use, then re-invoke with `--namespace <name>`.

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
```

- [ ] **Step 2: Verify the file is well-formed Markdown with valid frontmatter**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
.venv/bin/python -c "
import yaml
text = open('skills/endor-reports/SKILL.md').read()
assert text.startswith('---'), 'no frontmatter'
fm_end = text.index('---', 3)
front = yaml.safe_load(text[3:fm_end])
assert front['name'] == 'endor-reports'
assert isinstance(front['allowed-tools'], list)
assert any('run.py' in t for t in front['allowed-tools'])
print('SKILL.md frontmatter OK')
" 2>/dev/null || python3 -c "
import yaml
text = open('skills/endor-reports/SKILL.md').read()
fm_end = text.index('---', 3)
front = yaml.safe_load(text[3:fm_end])
print('SKILL.md frontmatter OK:', front['name'])
"
```

Expected: `SKILL.md frontmatter OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/SKILL.md
git commit -m "docs(endor-reports): add SKILL.md (v0.5 — remediation only)"
```

---

## Task 14: End-to-end smoke test (mocked endorctl)

A single test that invokes `run.py` with realistic CLI flags, fully mocks the `endorctl` subprocess, and asserts the resulting CSV matches expectations. This is the test that proves the wiring works.

**Files:**
- Create: `skills/endor-reports/tests/test_smoke_remediation.py`

- [ ] **Step 1: Write the smoke test**

File: `skills/endor-reports/tests/test_smoke_remediation.py`

```python
"""End-to-end smoke test: invoke run.py for the remediation source.

Mocks the `endorctl` subprocess so the test runs without a live Endor account.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

import lib.endorctl_client as ec_module
import run

SOURCES_DIR = Path(__file__).parent.parent / "sources"


def test_remediation_end_to_end(monkeypatch, tmp_path, finding_log_page1, finding_log_page2, auth_status_ok):
    queue = [
        json.dumps(auth_status_ok),       # endorctl auth status --json
        json.dumps(finding_log_page1),    # endorctl api list (page 1)
        json.dumps(finding_log_page2),    # endorctl api list (page 2)
    ]

    def fake_run(cmd, capture_output=True, text=True, timeout=None, check=False):
        out = queue.pop(0) if queue else ""
        return subprocess.CompletedProcess(args=cmd, returncode=0, stdout=out, stderr="")

    monkeypatch.setattr(ec_module, "_run_endorctl", fake_run)

    out_path = tmp_path / "remediation.csv"
    exit_code = run.main([
        "remediation",
        "--since", "2026-04-01",
        "--until", "2026-04-30",
        "--output", str(out_path),
    ], sources_dir=SOURCES_DIR)

    assert exit_code == 0
    assert out_path.exists()

    content = out_path.read_text()
    lines = content.splitlines()
    # Header + 3 records.
    assert len(lines) == 4
    header = lines[0]
    assert "Finding Log UUID" in header
    assert "CVE ID" in header
    assert "Resolved At" in header

    # Record 1: full data, CVE-2025-12345.
    assert "CVE-2025-12345" in lines[1]
    assert "fl-uuid-001" in lines[1]
    # iso_date formatter: meta.update_time "2026-04-10T14:30:00Z" → "2026-04-10".
    assert "2026-04-10" in lines[1]
    assert "2026-04-10T" not in lines[1]

    # Record 2: missing CVE → fallback "missing".
    assert "missing" in lines[2]

    # Record 3: full data, CVE-2024-99999.
    assert "CVE-2024-99999" in lines[3]
```

- [ ] **Step 2: Run the smoke test**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest tests/test_smoke_remediation.py -v
```

Expected: PASS.

- [ ] **Step 3: Run the full test suite**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/pytest -v
```

Expected: all tests PASS.

- [ ] **Step 4: Manual smoke test against a live endorctl (optional, requires authed user)**

If the engineer has `endorctl` authed locally, run:

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas/skills/endor-reports
.venv/bin/python run.py remediation --since 2026-04-01 --until 2026-04-30 --output /tmp/remediation.csv
head /tmp/remediation.csv
wc -l /tmp/remediation.csv
```

Expected: a CSV with the header row + N data rows. If `endorctl` is not authed, exit code 2 and a `needs_auth` message.

- [ ] **Step 5: Commit**

```bash
cd /Users/lmoreno/git/endor-internal/skills-ideas
git add skills/endor-reports/tests/test_smoke_remediation.py
git commit -m "test(endor-reports): add end-to-end smoke test for remediation source"
```

---

## Self-review

**Spec coverage check (against `2026-04-29-endor-reports-design.md` Sections referenced for v0.5):**

| Spec section | Task(s) covering it |
|---|---|
| 2 (architecture, layout) | Task 1 (scaffold) |
| 3 (source YAML schema, common header + api_list block) | Task 5 (loader), Task 10 (remediation.yaml) |
| 4.1 (CLI surface — subset relevant to v0.5) | Task 11 + 12 |
| 4.4 (auth pre-flight) | Task 7, integrated into Task 12 |
| 4.5 (api_list fetch loop) | Task 8, integrated into Task 12 |
| 4.8 (output path resolution) | Task 4, used in Task 12 |
| 4.9 (exit codes 0/1/2) | Task 12 (pipeline + error protocols) |
| 5.1 (CSV renderer) | Task 9 |
| 6 (SKILL.md) | Task 13 |
| 8 (allowlist) | Task 1 (scope-limited to v0.5 commands) |

Explicitly deferred and called out in plan headers, not implemented: 4.3 (widen flow), 4.6 (api_job loop), 4.7 (recipes/last-run), 5.2-5.5 (PDF rendering), 7 (scheduling), and the other 3 sources.

**Placeholder scan:** None. Every step has either runnable code, an exact command, or a concrete file body. No "TBD", no "implement appropriately", no "similar to X".

**Type consistency check:**
- `Source`, `ApiListConfig`, `Column`, `Parameter` — defined in Task 5 (`lib/source_loader.py`), referenced in Tasks 6 / 11 / 12 with matching field names.
- `AuthStatus` enum (`OK`, `NOT_AUTHED`, `NAMESPACE_AMBIGUOUS`) — defined in Task 7, referenced in Task 12 with same names.
- `AuthResult.status` / `.namespace` / `.message` — same.
- `EndorctlError` — defined in Task 8, caught in Task 12.
- `TemplateError` — defined in Task 3, caught in Task 12.
- `SourceLoadError` — defined in Task 5, caught in Task 11/12.
- `_run_endorctl` — single chokepoint in Task 7, monkeypatched in Tasks 7/8/12/14 tests with consistent signature.
- `resolve_output_path(source_name, explicit, output_dir, fallback_dir, now_utc=None, extension="csv")` — signature in Task 4, called in Task 12 with `extension` defaulting (no mismatch).
- `write_csv(path, headers, rows)` — signature in Task 9, called in Task 12 same shape.
- `project_records(records, columns)` — signature in Task 6, called in Task 12 same shape.
- `render(template, params)` — signature in Task 3, called in Task 12 same shape.
- `list_resource(resource, filter_expr, field_mask, namespace, page_size)` — signature in Task 8, called in Task 12 same shape.

All consistent.

**Scope check:** v0.5 plan is bounded to a single end-to-end vertical slice (one source, CSV only, no scheduling/recipes/widen). Suitable for a single execution session. v1 follow-up plan will extend horizontally (more sources, PDF, scheduling, etc.).

---

## Out of v0.5 (deferred to v1 plan)

- **PDF rendering** — frame + sections architecture, brand palette, logo, JSON→PDF adapter
- **Other 3 sources** — `pr_policy` (endorctl ScanResult), `findings_active_fixed` (active+logs reconciliation), `analytics` (api_job + JSON→PDF)
- **api_job mode** — submit/poll/download loop, post_process pipeline
- **Saved recipes + last-run state** — `--save-as`, `--recipe`, implicit `last/<source>.yaml` re-run
- **Widen-on-miss** — `--add-col` / `--drop-col` with four-tier behavior, in-place source YAML edits
- **Enrichments** — GHSA→CVE lookup, ecosystem label translation, reachability tag derivation
- **Scheduling artifacts** — `--schedule` subcommand emitting cron / launchd files
- **Structured `--json` exit-code-2 payloads** — for non-interactive callers
- **`--dry-run`** flag for resolved-config inspection
- **Bash startup wrapper for `endorctl init`** — handled by Claude per SKILL.md, not the runner

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-29-endor-reports-v0.5-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Good fit here because the 14 tasks are linear and each is small enough for a single subagent context.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

**Which approach?**
