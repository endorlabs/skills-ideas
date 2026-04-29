"""endor-reports runner CLI.

Stable subprocess shape: `python skills/endor-reports/run.py <source> [flags]`.
v0.5 supports the api_list pipeline end-to-end; api_job, scheduling, recipes,
widen-on-miss, and PDF rendering are deferred to v1.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Dict, Optional, Sequence

from lib.endorctl_client import AuthStatus, EndorctlError, check_auth, list_resource
from lib.filter_template import TemplateError, render
from lib.output import resolve_output_path
from lib.projection import project_records
from lib.renderers.csv import write_csv
from lib.source_loader import Source, SourceLoadError, load_source

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_SOURCES_DIR = SCRIPT_DIR / "sources"
DEFAULT_FALLBACK_OUTPUT = Path("~/.claude/endor-reports/output").expanduser()


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="run.py",
        description="Generate Endor Labs reports via endorctl.",
    )
    p.add_argument("source", nargs="?", help="Source name (see --list-sources)")
    p.add_argument("--list-sources", action="store_true", help="List available sources")
    p.add_argument("--show-source", metavar="NAME", help="Print the YAML of a source")
    p.add_argument("--since", metavar="YYYY-MM-DD", help="Maps to start_date parameter")
    p.add_argument("--until", metavar="YYYY-MM-DD", help="Maps to end_date parameter")
    p.add_argument("--param", action="append", default=[], metavar="KEY=VALUE",
                   help="Additional source parameters (repeatable)")
    p.add_argument("--namespace", help="Override endorctl namespace")
    p.add_argument("--output", help="Explicit output file path")
    p.add_argument("--output-dir", help="Output directory (file auto-named)")
    p.add_argument("--format", choices=["csv"], default="csv",
                   help="Output format (v0.5: csv only)")
    return p


def _list_sources(sources_dir: Path) -> int:
    files = sorted(sources_dir.glob("*.yaml"))
    if not files:
        print("(no sources found)")
        return 0
    for f in files:
        try:
            src = load_source(f)
            print(f"{src.name:<30} {src.description}")
        except SourceLoadError as e:
            print(f"{f.stem:<30} (load error: {e})", file=sys.stderr)
    return 0


def _show_source(name: str, sources_dir: Path) -> int:
    path = sources_dir / f"{name}.yaml"
    if not path.exists():
        print(f"unknown source: {name}", file=sys.stderr)
        return 1
    print(path.read_text())
    return 0


def _resolve_source_or_die(name: str, sources_dir: Path) -> Optional[Source]:
    path = sources_dir / f"{name}.yaml"
    if not path.exists():
        print(f"unknown source: {name}", file=sys.stderr)
        return None
    try:
        return load_source(path)
    except SourceLoadError as e:
        print(f"failed to load source `{name}`: {e}", file=sys.stderr)
        return None


def _resolve_params(source: Source, args: argparse.Namespace) -> Dict[str, object]:
    """Resolve report parameters from CLI flags.

    Precedence (low → high): source defaults → --since/--until shortcuts → --param k=v.
    --param therefore overrides --since/--until when keys collide.
    """
    params: Dict[str, object] = {}
    # Defaults from source.
    for p in source.parameters:
        if p.default is not None:
            params[p.name] = p.default
    # --since / --until shortcuts.
    if args.since:
        params["start_date"] = args.since
    if args.until:
        params["end_date"] = args.until
    # --param key=value (repeatable).
    for raw in args.param:
        if "=" not in raw:
            raise ValueError(f"--param requires KEY=VALUE form, got: {raw}")
        k, v = raw.split("=", 1)
        params[k.strip()] = v.strip()
    # Ensure every defined parameter has a value (None for optional + unset).
    for p in source.parameters:
        if p.name not in params:
            params[p.name] = None
    # Required-param check.
    missing = [
        p.name for p in source.parameters
        if p.required and (params.get(p.name) is None or params.get(p.name) == "")
    ]
    if missing:
        raise ValueError(f"missing required parameter(s): {', '.join(missing)}")
    return params


def _run_api_list(source: Source, params: Dict[str, object], args: argparse.Namespace) -> int:
    if source.api_list is None:
        print(f"source `{source.name}` has no api_list block", file=sys.stderr)
        return 1

    # Auth pre-flight.
    auth = check_auth(namespace=args.namespace)
    if auth.status == AuthStatus.NOT_AUTHED:
        print(f"needs_auth: {auth.message}\nRun `endorctl init` and re-invoke.", file=sys.stderr)
        return 2
    if auth.status == AuthStatus.NAMESPACE_AMBIGUOUS:
        print("needs_namespace: namespace could not be resolved. Pass --namespace.", file=sys.stderr)
        return 2

    # Render filter.
    try:
        filter_expr = render(source.api_list.filter_template, params)
    except TemplateError as e:
        print(f"filter template error: {e}", file=sys.stderr)
        return 1

    # Fetch.
    try:
        records = list(list_resource(
            resource=source.api_list.resource,
            filter_expr=filter_expr,
            field_mask=source.api_list.fetched_fields,
            namespace=auth.namespace,
            page_size=source.api_list.pagination_page_size,
        ))
    except EndorctlError as e:
        print(f"endorctl error: {e}", file=sys.stderr)
        return 1

    # Project + write.
    rows = project_records(records, source.api_list.default_columns)
    headers = [c.header for c in source.api_list.default_columns]
    out_path = resolve_output_path(
        source_name=source.name,
        explicit=args.output,
        output_dir=args.output_dir,
        fallback_dir=DEFAULT_FALLBACK_OUTPUT,
        extension=args.format,
    )
    n = write_csv(path=out_path, headers=headers, rows=rows)
    print(f"wrote {n} rows to {out_path}")
    return 0


def main(argv: Optional[Sequence[str]] = None, sources_dir: Optional[Path] = None) -> int:
    sources_dir = sources_dir or DEFAULT_SOURCES_DIR
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        if args.list_sources:
            return _list_sources(sources_dir)

        if args.show_source:
            return _show_source(args.show_source, sources_dir)

        if not args.source:
            parser.print_usage(sys.stderr)
            return 2

        source = _resolve_source_or_die(args.source, sources_dir)
        if source is None:
            return 1

        try:
            params = _resolve_params(source, args)
        except ValueError as e:
            print(str(e), file=sys.stderr)
            return 2

        return _run_api_list(source, params, args)
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
