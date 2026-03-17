# PureJinja

A Jinja2 template engine for PureBasic.

## What is PureJinja?

PureJinja is a feature-complete Jinja2 template engine ported from the Xojo
[JinjaX](https://github.com/) reference implementation. It is written in pure
procedural PureBasic -- no OOP, no external dependencies -- and compiles on
macOS, Windows, and Linux with PureBasic 6.x. The engine implements the classic
lexer, parser, renderer pipeline and covers all three feature tiers from the
original feasibility study.

**Current version:** 1.4.0 -- 599/599 tests passing, 34 source files.

## Quick Example

```purebasic
EnableExplicit
XIncludeFile "PureJinja.pbi"

Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
Protected NewMap vars.JinjaVariant::JinjaVariant()
JinjaVariant::StrVariant(@vars("name"), "World")

Protected result.s = JinjaEnv::RenderString(*env, "Hello, {{ name }}!", vars())
Debug result  ; -> Hello, World!

JinjaEnv::FreeEnvironment(*env)
ForEach vars()
  JinjaVariant::FreeVariant(@vars())
Next
```

## Feature Highlights

**Template Syntax**
- Variable interpolation: `{{ var }}`, `{{ obj.attr }}`, `{{ list[0] }}`
- Expressions: arithmetic, comparison, logical, string concatenation (`~`)
- Inline ternary: `value if condition else default`
- List literals `[a, b, c]` and dict literals `{"key": "value"}`

**Control Flow**
- `{% if %}` / `{% elif %}` / `{% else %}` / `{% endif %}`
- `{% for item in list %}` with full `loop` variable (`index`, `index0`, `first`, `last`, `length`, `revindex`, `revindex0`)
- `{% for ... %}{% else %}{% endfor %}` (empty-iterable fallback)
- `{% set var = expr %}` and dot-assignment `{% set ns.attr = value %}`
- Recursive for loops with `loop()` callable

**Filters**
- 35 built-in filters with aliases (`length`/`count`, `default`/`d`, `escape`/`e`)
- Filter chaining: `{{ value|trim|title|truncate(50) }}`
- Custom filter support via `RegisterFilter()`

**Template Composition**
- `{% extends "base.html" %}` / `{% block name %}` -- template inheritance (multi-level)
- `{% include "partial.html" %}` -- include with shared context
- `{% macro name(args) %}` -- reusable template functions
- `{% from "template" import macro_name %}` -- macro import

**Advanced**
- Whitespace control with strip markers (`{%-`, `-%}`, `{{-`, `-}}`)
- Raw blocks: `{% raw %}...{% endraw %}`
- `namespace()` for cross-scope variable assignment
- Global functions: `range()`, `dict()`, `joiner()`, `cycler()`
- Auto-escaping with MarkupSafe (`escape`/`safe` filters)
- `is`/`is not` tests: `none`, `defined`, `undefined`, `even`, `odd`, `number`, `string`
- FileSystem and Dict template loaders

## Installation

PureJinja is a single-include library. Add it to your project:

```purebasic
XIncludeFile "path/to/PureJinja.pbi"
```

All modules are auto-included in dependency order. No further includes are needed.

## Project Structure

```
pure_jinja/
  PureJinja.pbi                  Master include file
  Core/
    Constants.pbi                Enumerations (VariantType, TokenType, NodeType, ErrorCode)
    Variant.pbi                  JinjaVariant tagged union type
    Error.pbi                    Global error state
  Lexer/
    Token.pbi                    Token structure
    Lexer.pbi                    Tokenizer
  Parser/
    ASTNode.pbi                  AST node structure and constructors
    Parser.pbi                   Recursive descent parser
  Renderer/
    Context.pbi                  Scope stack
    Renderer.pbi                 Tree-walking renderer
  Environment/
    Environment.pbi              JinjaEnvironment, RenderString, RenderTemplate
    Filters.pbi                  35 built-in filter procedures
    Loader.pbi                   FileSystem and Dict template loaders
    MarkupSafe.pbi               HTML escaping
  Inheritance/
    ExtendsResolver.pbi          Template inheritance (extends/block merging)
  Tests/
    TestRunner.pb                Test entry point
    TestVariant.pbi              + 16 test modules
  templates/
    (55 acceptance test templates)
```

## Running Tests

```bash
# From the pure_jinja/ directory
pbcompiler -cl Tests/TestRunner.pb -o Tests/TestRunner
./Tests/TestRunner
```

Expected output:

```
=== PureJinja Test Suite ===
[PASS] ...
=== Results ===
Passed: 599/599
ALL TESTS PASSED
```

## Documentation

- [QUICKSTART.md](QUICKSTART.md) -- 5-minute hands-on tutorial
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) -- Full API reference, architecture, and module documentation
- [ARCHITECTURE.md](FEASIBILITY_STUDY.md) -- Original feasibility study and architecture design
- [CHANGELOG.md](CHANGELOG.md) -- Version history

## License

MIT License. See [LICENSE](LICENSE) for details.
