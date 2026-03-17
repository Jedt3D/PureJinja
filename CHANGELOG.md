# Changelog

All notable changes to PureJinja are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.0] - 2026-03-17

### Added
- `jinja_to_html.pb` CLI application: renders all 55 demo templates to static HTML in `jinja_to_html/`.
- Code walkthrough document (`JINJA_TO_HTML_WALKTHROUGH.md`) covering every PureJinja API pattern.

### Fixed
- Use-after-free crash in `Environment/Environment.pbi` when rendering templates that use `{% extends %}` with variables in blocks. The `RenderString()` procedure was prematurely freeing the child AST whose block-body nodes were shared (not deep-copied) by the merged AST from ExtendsResolver.

**Stats:** 599/599 tests passing, 34 source files. CLI app renders 55/55 templates.

## [1.3.0] - 2026-03-17

### Added
- `{% from "template" import macro_name %}` statement for importing macros from other templates.
- Support for importing multiple macros with comma-separated names.
- Recursive for loops with `{% for item in tree recursive %}` syntax.
- `loop()` callable inside recursive for loops for re-rendering with a new iterable.
- Lexer recognizes "from" and "import" as keywords.
- `RenderForItems()` helper shared by both normal iteration and recursive calls.

**Stats:** 599/599 tests passing, 10,653 lines compiled, 33 source files. All Tier 3 features complete.

## [1.2.0] - 2026-03-17

### Added
- `namespace()` function for creating mutable maps that persist across scopes (for loops, if blocks).
- Dot-assignment syntax: `{% set ns.attr = value %}`.
- Global function `dict()` for creating empty dictionaries.
- Global function `joiner(sep)` that outputs a separator between iterations, skipping the first call.
- Global function `cycler(items...)` that cycles through values.
- `SetVariableMapEntry()` in Context.pbi for in-place map modification without deep-copy interference.
- Global state maps for tracking joiner/cycler call history.

**Stats:** 586/586 tests passing, 10,100 lines compiled, 32 source files.

## [1.1.0] - 2026-03-17

### Added
- Dict literal syntax: `{"key": "value", "key2": expr}` in template expressions.
- Support for nested dicts, variable values, dot/bracket access, trailing commas, and empty dicts.
- 8 new filters (35 total): `indent(width)`, `wordwrap(width)`, `center(width)`, `urlencode`, `tojson`, `unique`, `map(attribute)`, `items`.
- `VMapKeys()` added to Variant API for map key iteration.

### Changed
- Lexer updated to emit `{`/`}` tokens for dict literal support.
- Parser updated with dict parsing in `ParsePrimaryExpression`.
- Renderer updated with `EvaluateDictLiteral` for dict evaluation.

**Stats:** 563/563 tests passing, 9,689 lines compiled, 30 source files.

## [1.0.0] - 2026-03-17

### Added
- Auto-resolve inheritance: `RenderString()` and `RenderTemplate()` now auto-detect `{% extends %}` and resolve inheritance before rendering, eliminating the need for manual `JinjaExtends::Resolve()` calls.
- Whitespace control via strip markers: `{%-`, `-%}`, `{{-`, `-}}`, `{#-`, `-#}` remove adjacent whitespace from text nodes.
- Raw blocks: `{% raw %}...{% endraw %}` outputs content literally without Jinja processing.
- Whitespace stripping handled entirely in the Lexer via a post-processing pass.
- Raw blocks handled in the Lexer as a single TK_Data token, requiring no Parser or Renderer changes.

**Stats:** 497/497 tests passing, 8,583 lines compiled, 27 source files.

## [0.9.0]

### Added
- Full acceptance test coverage for all 55 templates.
- Inheritance tests (43 tests) validating extends/block for single-level, multi-block, variables-in-blocks, 3-level grandchild chains, and logic-in-blocks.
- Include tests verifying partial loading via DictLoader.
- Real-world tests covering product lists, user profiles, email templates, table reports with `loop.index`, navigation with active-URL comparison, and error pages with `default()` filters.

**Stats:** 466/466 tests passing, 7,976 lines compiled.

## [0.8.0]

### Fixed
- `JinjaEnv::RenderString()` and `RenderTemplate()` now complete the end-to-end rendering pipeline correctly.
- Circular dependency between `Environment.pbi` and `Renderer.pbi` resolved via a runtime callback: `Renderer.pbi` calls `JinjaEnv::RegisterRenderer(@Render())` at load time, allowing `RenderString()` to invoke the renderer without a compile-time circular include.

### Added
- Acceptance tests against real HTML templates.

## [0.7.0]

### Added
- Comprehensive test suite with unit tests expanded across all modules: lexer, parser, renderer, filters, inheritance, and environment.

## [0.6.0]

### Added
- Phase 0-5 complete: Core, Lexer, Parser, Renderer, Environment, and Inheritance modules.
- JinjaVariant tagged union type with Null, Boolean, Integer, Double, String, Markup, List, and Map types.
- Lexer with support for variable blocks, statement blocks, comments, string/number literals, keywords, and operators.
- Recursive descent parser with full expression precedence (9 levels).
- Tree-walking renderer with variable interpolation, control flow (if/elif/else, for loops), set statements, and scope isolation.
- Environment with auto-escaping, FileSystemLoader, DictLoader, and 25 built-in filters.
- Template inheritance with extends/block and multi-level inheritance support.
- Template include with shared context.

**Stats:** 5,057 lines across 17 files. All 38 variant unit tests passing. Compilation clean with PureBasic 6.30 on macOS.

## [0.0.0]

### Added
- Initial project setup and feasibility study.
- Test templates copied from Xojo JinjaX reference implementation.
