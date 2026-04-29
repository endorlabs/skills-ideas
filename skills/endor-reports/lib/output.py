"""Resolve output path for a report.

Resolution order (low → high specificity):
  1. fallback_dir / <source>_<timestamp>.csv   (used when nothing else provided)
  2. <output_dir> / <source>_<timestamp>.csv
  3. <explicit_path>                            (verbatim)
"""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def resolve_output_path(
    source_name: str,
    explicit: Optional[str],
    output_dir: Optional[str],
    fallback_dir: Path,
    now_utc: Optional[str] = None,
    extension: str = "csv",
) -> Path:
    """Return the resolved output Path, creating parent directories as needed."""
    if explicit:
        path = Path(explicit).expanduser().resolve()
        path.parent.mkdir(parents=True, exist_ok=True)
        return path

    timestamp = now_utc or _utc_timestamp()
    filename = f"{source_name}_{timestamp}.{extension}"

    if output_dir:
        directory = Path(output_dir).expanduser().resolve()
    else:
        directory = Path(fallback_dir).expanduser().resolve()

    directory.mkdir(parents=True, exist_ok=True)
    return directory / filename
