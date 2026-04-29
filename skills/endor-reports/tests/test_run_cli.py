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
        assert "Description" in text  # new column header
        assert "fl-uuid-001" in text
        assert "fl-uuid-002" in text
        assert "fl-uuid-003" in text
        # GHSA prefix appears in Description for SCA findings.
        assert "GHSA-aaaa-bbbb-cccc" in text
        # Empty description on fl-uuid-002 → empty cell (fallback "").
        rows = text.splitlines()
        # Row 2 has empty description; verify by checking presence of consecutive commas
        # OR by checking GHSA is NOT on row 2.
        assert "GHSA-pppp" not in rows[2]  # row 2 is fl-uuid-002 (license risk, no GHSA in description)

    def test_optional_project_param_threads_through_filter(self, mock_endorctl, tmp_path):
        out_path = tmp_path / "out.csv"
        run.main([
            "remediation",
            "--since", "2026-04-01",
            "--until", "2026-04-30",
            "--param", "project_uuid=abc123abc123abc123abc123",
            "--output", str(out_path),
        ], sources_dir=SOURCES_DIR)
        list_call = next(c for c in mock_endorctl if "list" in c and "api" in c)
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

    def test_endorctl_failure_exits_1(self, monkeypatch, tmp_path, capsys, auth_status_ok):
        responses = [_json.dumps(auth_status_ok)]  # auth ok, then list fails

        def fake_run(cmd, capture_output=True, text=True, timeout=None, check=False):
            if responses:
                return _subprocess.CompletedProcess(
                    args=cmd, returncode=0, stdout=responses.pop(0), stderr="",
                )
            return _subprocess.CompletedProcess(
                args=cmd, returncode=1, stdout="", stderr="api unreachable",
            )

        monkeypatch.setattr(ec_module, "_run_endorctl", fake_run)
        exit_code = run.main([
            "remediation",
            "--since", "2026-04-01",
            "--until", "2026-04-30",
            "--output", str(tmp_path / "out.csv"),
        ], sources_dir=SOURCES_DIR)
        assert exit_code == 1
        captured = capsys.readouterr()
        assert "endorctl error" in captured.err.lower()
        assert "api unreachable" in captured.err

    def test_template_error_exits_1(self, monkeypatch, tmp_path, capsys, auth_status_ok):
        # Patch the filter renderer to raise TemplateError so we exercise the exit-1 branch.
        import lib.filter_template as ft_module
        orig_render = ft_module.render

        def boom_render(template, params):
            raise ft_module.TemplateError("simulated render failure")

        # Auth must succeed before render is called.
        def fake_run(cmd, capture_output=True, text=True, timeout=None, check=False):
            return _subprocess.CompletedProcess(
                args=cmd, returncode=0, stdout=_json.dumps(auth_status_ok), stderr="",
            )

        monkeypatch.setattr(ec_module, "_run_endorctl", fake_run)
        # Patch run.render (the imported binding inside run.py).
        monkeypatch.setattr(run, "render", boom_render)

        exit_code = run.main([
            "remediation",
            "--since", "2026-04-01",
            "--until", "2026-04-30",
            "--output", str(tmp_path / "out.csv"),
        ], sources_dir=SOURCES_DIR)
        assert exit_code == 1
        captured = capsys.readouterr()
        assert "filter template error" in captured.err.lower()
        assert "simulated render failure" in captured.err
