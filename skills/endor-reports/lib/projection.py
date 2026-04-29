"""Apply column projections to raw records.

A Column maps a dotted source path (e.g. "spec.vulnerability.cve_id") to a header.
When the looked-up value is None, an empty string, or an empty list, the column's
fallback is used. Lists are pipe-joined. Optional named formatters transform the
value before stringification.
"""
from __future__ import annotations

from typing import Any, Iterable, List, Mapping

from lib.source_loader import Column


class ProjectionError(ValueError):
    """Raised when a projection cannot be applied to a record."""


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
    if isinstance(value, (str, list)) and len(value) == 0:
        return True
    return False


def _apply_formatter(value: Any, formatter: str) -> str:
    if formatter == "iso_date":
        if not isinstance(value, str):
            return str(value)
        # ISO 8601 timestamps look like "2026-04-29T14:22:00Z" → keep the date prefix.
        return value.split("T", 1)[0] if "T" in value else value
    raise ProjectionError(f"unknown formatter: {formatter}")


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
