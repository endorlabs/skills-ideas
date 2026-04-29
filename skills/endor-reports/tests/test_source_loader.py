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

    def test_parameter_missing_name_raises(self, tmp_path):
        path = _write(tmp_path, "x", """
            name: x
            description: y
            modes: [api_list]
            default_mode: api_list
            parameters:
              - { type: date, required: true }
            api_list:
              resource: Finding
              filter_template: ""
              fetched_fields: []
              default_columns: []
        """)
        with pytest.raises(SourceLoadError, match="parameter: missing required key: name"):
            load_source(path)

    def test_column_missing_header_raises(self, tmp_path):
        path = _write(tmp_path, "x", """
            name: x
            description: y
            modes: [api_list]
            default_mode: api_list
            api_list:
              resource: Finding
              filter_template: ""
              fetched_fields: []
              default_columns:
                - { source: spec.foo }
        """)
        with pytest.raises(SourceLoadError, match="column: missing required key: header"):
            load_source(path)

    def test_empty_name_raises(self, tmp_path):
        path = _write(tmp_path, "x", """
            name: ""
            description: y
            modes: [api_list]
            default_mode: api_list
            api_list:
              resource: Finding
              filter_template: ""
              fetched_fields: []
              default_columns: []
        """)
        with pytest.raises(SourceLoadError, match="name must be a non-empty string"):
            load_source(path)


class TestRealRemediationSource:
    def test_loads_shipped_remediation(self):
        from pathlib import Path
        path = Path(__file__).parent.parent / "sources" / "remediation.yaml"
        src = load_source(path)
        assert src.name == "remediation"
        assert src.api_list is not None
        assert src.api_list.resource == "FindingLog"
        assert src.api_list.pagination_page_size == 500
        assert len(src.api_list.fetched_fields) == 12
        # Ensure the column we care about is present and uses iso_date formatter.
        resolved_at = next(c for c in src.api_list.default_columns if c.header == "Resolved At")
        assert resolved_at.format == "iso_date"
        assert resolved_at.source == "meta.update_time"
        introduced_at = next(c for c in src.api_list.default_columns if c.header == "Introduced At")
        assert introduced_at.format == "iso_date"
        assert introduced_at.source == "spec.introduced_at"
        type_col = next(c for c in src.api_list.default_columns if c.header == "Type")
        assert type_col.source == "meta.name"
        # Optional param marked correctly.
        proj = next(p for p in src.parameters if p.name == "project_uuid")
        assert proj.required is False
