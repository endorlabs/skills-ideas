"""Tests for the endorctl subprocess client (auth probe + paginated list)."""
from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import List

import pytest

from lib import endorctl_client as ec
from lib.endorctl_client import AuthStatus, DEFAULT_AUTH_TIMEOUT_SECONDS


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


def test_default_auth_timeout_is_set():
    assert DEFAULT_AUTH_TIMEOUT_SECONDS > 0
    assert DEFAULT_AUTH_TIMEOUT_SECONDS <= 60


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


class TestAuthMalformedResponse:
    def test_zero_returncode_with_empty_stdout_is_ambiguous(self, patch_runner):
        patch_runner([FakeRun(stdout="", returncode=0)])
        result = ec.check_auth()
        assert result.status == AuthStatus.NAMESPACE_AMBIGUOUS
        assert "no parseable" in (result.message or "")

    def test_zero_returncode_with_unparseable_json_is_ambiguous(self, patch_runner):
        patch_runner([FakeRun(stdout="not valid json", returncode=0)])
        result = ec.check_auth()
        assert result.status == AuthStatus.NAMESPACE_AMBIGUOUS
        assert "no parseable" in (result.message or "")


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
        # Global -n <ns> comes before the verb.
        assert cmd[:3] == ["endorctl", "-n", "acme-tenant"]
        assert cmd[3:7] == ["api", "list", "-r", "FindingLog"]
        # No --output-format flag (JSON is default).
        assert "--output-format" not in cmd
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
        # First call must NOT carry --page-id (we don't have it yet).
        assert "--page-id" not in runner.calls[0]
        # Second call must include the page id.
        assert "--page-id" in runner.calls[1]
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

    def test_empty_field_mask_raises(self, patch_runner):
        # No FakeRun queued — the guard fires before any subprocess call.
        with pytest.raises(ec.EndorctlError, match="field_mask cannot be empty"):
            list(ec.list_resource(
                resource="FindingLog",
                filter_expr="x",
                field_mask=[],
                namespace="ns",
                page_size=10,
            ))

    def test_default_list_timeout_is_set(self):
        # Module-level constant exists and is reasonable.
        assert ec.DEFAULT_LIST_PAGE_TIMEOUT_SECONDS > 0
        assert ec.DEFAULT_LIST_PAGE_TIMEOUT_SECONDS <= 600
