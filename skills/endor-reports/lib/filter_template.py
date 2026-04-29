"""Mustache-style filter template renderer.

Supports:
  - {{var}}                 — variable substitution; missing vars raise TemplateError.
  - {{#if var}}...{{/if}}   — conditional block; renders body iff var is truthy AND defined.

Deliberately limited: no nested conditionals, no loops, no helpers. If a source's
filter needs more complexity, it should pre-compute values in Python before calling render().
"""
from __future__ import annotations

import re
from typing import Any, Mapping


class TemplateError(ValueError):
    pass


_IF_BLOCK_RE = re.compile(r"\{\{#if\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}(.*?)\{\{/if\}\}", re.DOTALL)
_VAR_RE = re.compile(r"\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}")


def render(template: str, params: Mapping[str, Any]) -> str:
    """Render a Mustache-style template string against the provided params.

    Raises TemplateError if a {{var}} reference is missing from params (outside an {{#if}} block).
    Inside {{#if var}}...{{/if}}, a missing or falsy var causes the block to be skipped silently.
    """
    # Pass 1: process {{#if var}}...{{/if}} blocks.
    def _resolve_if(match: re.Match) -> str:
        var_name = match.group(1)
        body = match.group(2)
        value = params.get(var_name)
        if not value:
            return ""
        return body

    rendered = _IF_BLOCK_RE.sub(_resolve_if, template)

    # Pass 2: substitute remaining {{var}} references; missing → error.
    def _resolve_var(match: re.Match) -> str:
        var_name = match.group(1)
        if var_name not in params:
            raise TemplateError(f"undefined variable: {var_name}")
        return str(params[var_name])

    result = _VAR_RE.sub(_resolve_var, rendered)
    if "{{" in result:
        raise TemplateError(f"unrendered template syntax remains: {result!r}")
    return result
