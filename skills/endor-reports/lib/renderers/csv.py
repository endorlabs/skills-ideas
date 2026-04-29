"""CSV renderer — RFC 4180 quoting, UTF-8, LF line endings, streaming write."""
from __future__ import annotations

import csv
from pathlib import Path
from typing import Iterable, List, Mapping


def write_csv(path: Path, headers: List[str], rows: Iterable[Mapping[str, str]]) -> int:
    """Write headers + rows to `path`. Returns the number of data rows written."""
    count = 0
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=headers,
            quoting=csv.QUOTE_MINIMAL,
            lineterminator="\n",
            extrasaction="ignore",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({h: row.get(h, "") for h in headers})
            count += 1
    return count
