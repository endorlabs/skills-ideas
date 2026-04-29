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
    # Header has the new columns.
    assert "Finding Log UUID" in header
    assert "Description" in header
    assert "Severity" in header
    assert "Resolved At" in header
    assert "Type" in header

    # Record 1: SCA finding, has GHSA in description.
    assert "fl-uuid-001" in lines[1]
    assert "GHSA-aaaa-bbbb-cccc" in lines[1]
    assert "FINDING_LEVEL_CRITICAL" in lines[1]
    # iso_date formatter: meta.update_time "2026-04-10T14:30:00Z" → "2026-04-10".
    assert "2026-04-10" in lines[1]
    assert "2026-04-10T" not in lines[1]

    # Record 2: license risk, empty description.
    assert "fl-uuid-002" in lines[2]
    assert "bad_license" in lines[2]  # the meta.name "Type" column
    assert "GHSA" not in lines[2]  # no GHSA in license-risk description

    # Record 3: SCA finding with GHSA-pppp prefix.
    assert "fl-uuid-003" in lines[3]
    assert "GHSA-pppp-qqqq-rrrr" in lines[3]
