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

    def test_explicit_path_creates_missing_parent(self, tmp_path):
        explicit = tmp_path / "deeply" / "nested" / "report.csv"
        assert not explicit.parent.exists()
        result = resolve_output_path(
            source_name="remediation",
            explicit=str(explicit),
            output_dir=None,
            fallback_dir=tmp_path / "fallback",
            now_utc="20260429_120000",
        )
        assert result == explicit
        assert explicit.parent.exists()


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
