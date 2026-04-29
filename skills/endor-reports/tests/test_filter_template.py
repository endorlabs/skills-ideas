"""Tests for the Mustache-style filter template renderer."""
from __future__ import annotations

import pytest

from lib.filter_template import render, TemplateError


class TestSimpleVarSubstitution:
    def test_single_var(self):
        assert render("hello {{name}}", {"name": "world"}) == "hello world"

    def test_multiple_vars(self):
        assert render("{{a}}-{{b}}", {"a": "x", "b": "y"}) == "x-y"

    def test_repeated_var(self):
        assert render("{{x}} and {{x}}", {"x": "z"}) == "z and z"

    def test_no_vars(self):
        assert render("plain text", {}) == "plain text"

    def test_var_with_spaces_inside_braces_is_trimmed(self):
        assert render("{{ name }}", {"name": "x"}) == "x"

    def test_missing_var_raises(self):
        with pytest.raises(TemplateError, match="undefined variable: name"):
            render("hello {{name}}", {})


class TestConditionalBlocks:
    def test_truthy_value_renders_block(self):
        tpl = "a {{#if x}}b {{x}} c{{/if}} d"
        assert render(tpl, {"x": "MID"}) == "a b MID c d"

    def test_falsy_value_skips_block(self):
        tpl = "a {{#if x}}b{{/if}} c"
        assert render(tpl, {"x": None}) == "a  c"

    def test_missing_var_in_if_skips_block(self):
        tpl = "a {{#if x}}b{{/if}} c"
        assert render(tpl, {}) == "a  c"

    def test_empty_string_is_falsy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": ""}) == ""

    def test_zero_is_falsy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": 0}) == ""

    def test_false_is_falsy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": False}) == ""

    def test_nonempty_string_is_truthy(self):
        tpl = "{{#if x}}YES{{/if}}"
        assert render(tpl, {"x": "anything"}) == "YES"

    def test_two_adjacent_blocks_render_independently(self):
        tpl = "{{#if a}}A{{/if}}{{#if b}}B{{/if}}"
        assert render(tpl, {"a": 1, "b": 1}) == "AB"
        assert render(tpl, {"a": 1, "b": 0}) == "A"
        assert render(tpl, {"a": 0, "b": 1}) == "B"
        assert render(tpl, {"a": 0, "b": 0}) == ""

    def test_nested_if_raises_via_unrendered_check(self):
        tpl = "{{#if a}}outer {{#if b}}inner{{/if}} after{{/if}}"
        with pytest.raises(TemplateError, match="unrendered template syntax"):
            render(tpl, {"a": 1, "b": 1})


class TestRealisticEndorFilterTemplate:
    def test_remediation_filter(self):
        tpl = (
            'spec.operation == "OPERATION_DELETE"\n'
            'and meta.update_time >= "{{start_date}}"\n'
            'and meta.update_time <= "{{end_date}}"\n'
            '{{#if project_uuid}}and spec.project_uuid == "{{project_uuid}}"{{/if}}'
        )
        params = {
            "start_date": "2026-04-01",
            "end_date": "2026-04-30",
            "project_uuid": "abc123abc123abc123abc123",
        }
        out = render(tpl, params)
        assert 'meta.update_time >= "2026-04-01"' in out
        assert 'meta.update_time <= "2026-04-30"' in out
        assert 'spec.project_uuid == "abc123abc123abc123abc123"' in out

    def test_remediation_filter_without_optional_project(self):
        tpl = (
            'meta.update_time >= "{{start_date}}"\n'
            '{{#if project_uuid}}and spec.project_uuid == "{{project_uuid}}"{{/if}}'
        )
        params = {"start_date": "2026-04-01", "project_uuid": None}
        out = render(tpl, params)
        assert 'meta.update_time >= "2026-04-01"' in out
        assert "project_uuid" not in out
