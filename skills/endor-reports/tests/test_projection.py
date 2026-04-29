"""Tests for the column projection module."""
from __future__ import annotations

import pytest

from lib.projection import project_record, project_records, lookup_path, ProjectionError
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
        with pytest.raises(ProjectionError, match="unknown formatter: bogus"):
            project_record(record, cols)

    def test_missing_value_with_formatter_uses_fallback_not_formatted(self):
        record = {}
        cols = [Column(header="Date", source="t", format="iso_date", fallback="N/A")]
        assert project_record(record, cols) == {"Date": "N/A"}
