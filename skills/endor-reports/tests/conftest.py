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
