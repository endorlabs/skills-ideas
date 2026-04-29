"""Load and validate source YAML files into typed dataclasses.

v0.5 supports the common header + the api_list block. The api_job block is
parsed-but-stored-as-None so v1 can extend without schema breakage.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, List, Mapping, Optional

import yaml


class SourceLoadError(ValueError):
    pass


VALID_MODES = {"api_list", "api_job"}


@dataclass(frozen=True)
class Parameter:
    name: str
    type: str
    required: bool
    default: Any = None


@dataclass(frozen=True)
class Column:
    header: str
    source: str
    fallback: str = ""
    format: Optional[str] = None


@dataclass(frozen=True)
class ApiListConfig:
    resource: str
    filter_template: str
    fetched_fields: List[str]
    default_columns: List[Column]
    pagination_page_size: int = 500


@dataclass(frozen=True)
class Source:
    name: str
    description: str
    modes: List[str]
    default_mode: str
    default_format: List[str]
    parameters: List[Parameter]
    api_list: Optional[ApiListConfig]
    api_job: Optional[dict]  # opaque in v0.5


def _require(d: Mapping[str, Any], key: str, ctx: str = "source") -> Any:
    if key not in d:
        raise SourceLoadError(f"{ctx}: missing required key: {key}")
    return d[key]


def _parse_parameter(d: Mapping[str, Any]) -> Parameter:
    name = _require(d, "name", ctx="parameter")
    return Parameter(
        name=name,
        type=d.get("type", "string"),
        required=bool(d.get("required", False)),
        default=d.get("default"),
    )


def _parse_column(d: Mapping[str, Any]) -> Column:
    return Column(
        header=_require(d, "header", ctx="column"),
        source=_require(d, "source", ctx="column"),
        fallback=str(d.get("fallback", "")),
        format=d.get("format"),
    )


def _parse_api_list(d: Mapping[str, Any]) -> ApiListConfig:
    pagination = d.get("pagination") or {}
    return ApiListConfig(
        resource=_require(d, "resource", ctx="api_list"),
        filter_template=_require(d, "filter_template", ctx="api_list"),
        fetched_fields=list(d.get("fetched_fields", [])),
        default_columns=[_parse_column(c) for c in d.get("default_columns", [])],
        pagination_page_size=int(pagination.get("page_size", 500)),
    )


def load_source(path: Path) -> Source:
    """Load a source YAML file and return a validated Source dataclass."""
    raw = yaml.safe_load(Path(path).read_text())
    if not isinstance(raw, dict):
        raise SourceLoadError(f"{path}: file must contain a YAML mapping at the top level")

    name = _require(raw, "name")
    if not isinstance(name, str) or not name.strip():
        raise SourceLoadError(f"{path}: name must be a non-empty string")
    description = raw.get("description", "")
    modes = list(raw.get("modes", []))
    if not modes:
        raise SourceLoadError(f"{path}: at least one mode required in `modes`")
    for m in modes:
        if m not in VALID_MODES:
            raise SourceLoadError(f"{path}: invalid mode: {m}; valid: {sorted(VALID_MODES)}")
    default_mode = raw.get("default_mode", modes[0])
    if default_mode not in modes:
        raise SourceLoadError(f"{path}: default_mode `{default_mode}` not in modes {modes}")

    default_format = list(raw.get("default_format", ["csv"]))
    parameters = [_parse_parameter(p) for p in raw.get("parameters", [])]

    api_list = None
    if "api_list" in modes:
        if "api_list" not in raw:
            raise SourceLoadError(f"{path}: api_list block missing but listed in modes")
        api_list = _parse_api_list(raw["api_list"])

    api_job = raw.get("api_job")  # opaque

    return Source(
        name=name,
        description=description,
        modes=modes,
        default_mode=default_mode,
        default_format=default_format,
        parameters=parameters,
        api_list=api_list,
        api_job=api_job,
    )
