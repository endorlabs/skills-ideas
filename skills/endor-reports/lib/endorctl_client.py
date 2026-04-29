"""Subprocess wrappers for endorctl. v0.5 covers `auth status` and `api list`."""
from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from enum import Enum
from typing import Iterator, List, Optional


DEFAULT_AUTH_TIMEOUT_SECONDS = 30
DEFAULT_LIST_PAGE_TIMEOUT_SECONDS = 300  # 5 minutes per page; lists with --page-size 500 can be slow on cold caches


class AuthStatus(Enum):
    OK = "ok"
    NOT_AUTHED = "not_authed"
    NAMESPACE_AMBIGUOUS = "namespace_ambiguous"


@dataclass(frozen=True)
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
    json_proc = _run_endorctl(["endorctl", "auth", "status", "--json"], timeout=DEFAULT_AUTH_TIMEOUT_SECONDS)
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

    # If endorctl exited cleanly but we couldn't extract a status, that's a
    # malformed-but-successful response — surface ambiguity rather than NOT_AUTHED.
    if json_proc.returncode == 0:
        return AuthResult(
            status=AuthStatus.NAMESPACE_AMBIGUOUS,
            message="endorctl returned no parseable auth status",
        )

    # Fallback: try plain text form for older endorctl versions that don't support --json.
    stderr = json_proc.stderr or ""
    if "unknown flag" in stderr or "flag provided but not defined" in stderr or "unknown command" in stderr:
        text_proc = _run_endorctl(["endorctl", "auth", "status"], timeout=DEFAULT_AUTH_TIMEOUT_SECONDS)
        if text_proc.returncode != 0:
            return AuthResult(status=AuthStatus.NOT_AUTHED, message=(text_proc.stderr or "not authenticated").strip())
        ns = namespace or _parse_text_auth_status(text_proc.stdout)
        if not ns:
            return AuthResult(status=AuthStatus.NAMESPACE_AMBIGUOUS, message="no namespace resolved")
        return AuthResult(status=AuthStatus.OK, namespace=ns)

    return AuthResult(status=AuthStatus.NOT_AUTHED, message=stderr.strip() or "not authenticated")


class EndorctlError(RuntimeError):
    pass


def list_resource(
    resource: str,
    filter_expr: str,
    field_mask: List[str],
    namespace: str,
    page_size: int = 500,
    timeout: Optional[int] = DEFAULT_LIST_PAGE_TIMEOUT_SECONDS,
) -> Iterator[dict]:
    """Stream records from `endorctl api list -r <Resource>`, following pagination.

    Yields one record (dict) at a time. Raises EndorctlError on non-zero exit
    or unparseable JSON.
    """
    if not field_mask:
        raise EndorctlError("field_mask cannot be empty")

    next_page_id: Optional[str] = None
    while True:
        cmd = [
            "endorctl", "-n", namespace, "api", "list",
            "-r", resource,
            "--filter", filter_expr,
            "--field-mask", ",".join(field_mask),
            "--page-size", str(page_size),
        ]
        if next_page_id:
            cmd.extend(["--page-id", next_page_id])

        proc = _run_endorctl(cmd, timeout=timeout)
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

        next_page_id = (list_block.get("response") or {}).get("next_page_id")
        if not next_page_id:
            break
