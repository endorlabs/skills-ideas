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
