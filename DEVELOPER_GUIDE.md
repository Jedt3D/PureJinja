# PureJinja Developer Guide

PureJinja is a Jinja2 template engine written in PureBasic. It implements the classic
lexer → parser → renderer pipeline in procedural PureBasic without OOP inheritance.
This guide is intended for developers who want to use PureJinja in a project, extend it
with custom filters, or contribute to the engine itself.

Current version: 0.8.0 (Phases 0–5 complete, RenderString working)

---

## Architecture

### Module Dependency Diagram

```
PureJinja.pbi  (master include - include this in your project)
│
├── Core/Constants.pbi          (enumerations: VariantType, TokenType, NodeType, ErrorCode)
├── Core/Error.pbi              (global error state; depends on Constants)
├── Core/Variant.pbi            (JinjaVariant tagged union; depends on Constants, Error)
│
├── Lexer/Token.pbi             (Token structure + debug name helper)
├── Lexer/Lexer.pbi             (tokenizer; depends on Token, Constants)
│
├── Parser/ASTNode.pbi          (ASTNode structure + constructors; depends on Constants)
├── Parser/Parser.pbi           (recursive descent parser; depends on ASTNode, Token, Lexer, Error)
│
├── Environment/MarkupSafe.pbi  (HTML escaping; depends on Variant)
├── Environment/Filters.pbi     (built-in filter procedures; depends on Variant, MarkupSafe)
├── Environment/Loader.pbi      (FileSystem + Dict loaders; depends on Error)
├── Environment/Environment.pbi (JinjaEnvironment; depends on all of the above)
│
├── Renderer/Context.pbi        (scope stack; depends on Variant)
├── Renderer/Renderer.pbi       (tree-walker; depends on everything above)
│
└── Inheritance/ExtendsResolver.pbi  (block merging; depends on Renderer, Lexer, Parser)
```

### Data Flow

```
Template String
      |
      v
JinjaLexer::Tokenize()
      |
      v
List of Token (TK_Data, TK_VariableBegin, TK_Name, TK_Operator, ...)
      |
      v
JinjaParser::Parse()
      |
      v
ASTNode tree (NODE_Template root -> NODE_Text, NODE_Output, NODE_If, NODE_For, ...)
      |
      v  [optional: JinjaExtends::Resolve() merges parent/child blocks]
      |
      v
JinjaRenderer::Render()  +  JinjaContext (scope stack of JinjaVariant maps)
      |
      v
Output String
```

### Key Design Decisions

**Tagged union Variant** — PureBasic has no dynamic typing. Every template value (variable,
expression result, filter argument) is a `JinjaVariant` structure with a `VType` field
that selects which storage field is active (`IntVal`, `DblVal`, `StrVal`, `ListPtr`,
`MapPtr`). All variant operations are dispatched with `Select *v\VType`.

**Select/Case AST dispatch** — PureBasic has no class inheritance, so the renderer and
evaluator dispatch on `*node\NodeType` using `Select/Case`. All 19 node types share a
single flat `ASTNode` structure; unused fields are zero. This is the standard pattern for
tree-walking interpreters in C and maps cleanly to PureBasic.

**Global error state** — There are no exceptions. `JinjaError::SetError()` records the
first error that occurs. All procedures check `JinjaError::HasError()` at the top and
return early. The caller inspects the error after the top-level call returns and calls
`JinjaError::ClearError()` before the next operation.

**No OOP** — The codebase uses PureBasic `DeclareModule`/`Module` for namespacing and
`Prototype` for filter function pointers. There are no objects, no constructors, no
inheritance. Data is passed as pointers to allocated structures.

**Scope stack** — `JinjaContext` is a `List` of `ScopeLevel`, each containing a `Map` of
`JinjaVariant`. `GetVariable()` walks from the last (innermost) element to the first
(global). `PushScope()`/`PopScope()` are called around for-loop iterations and macro calls.

**Filter function pointers** — All filters share the prototype
`ProtoFilter(*value, *args, argCount, *result)`. The environment stores a `Map` of
filter name → procedure address. Filters are called via the prototype without knowing
the callee at compile time. Custom filters use the same prototype.

**Environment/Renderer circular dependency resolution** — `Environment.pbi` must be
compiled before `Renderer.pbi` (it declares the `JinjaEnvironment` structure that the
renderer needs), yet `RenderString()` in the environment needs to call
`JinjaRenderer::Render()`. This would create a circular include. The solution is a
runtime callback: `Environment.pbi` declares a `ProtoRenderCallback` prototype and stores
a global `gRenderCallback` pointer. At the bottom of `Renderer.pbi`, after the `Module`
block closes, a single module-level statement calls `JinjaEnv::RegisterRenderer(@Render())`
to install the callback. `PureJinja.pbi` includes `Environment.pbi` first and
`Renderer.pbi` second, so the callback is set before any user code runs. `RenderString()`
and `RenderTemplate()` invoke the renderer through this pointer.

---

## Module Reference

### Core

#### Constants.pbi — `DeclareModule Jinja`

Defines all enumerations. No procedures. Key enumerations:

| Enumeration | Values |
|-------------|--------|
| `VariantType` | `#VT_Null`, `#VT_Boolean`, `#VT_Integer`, `#VT_Double`, `#VT_String`, `#VT_List`, `#VT_Map`, `#VT_Markup` |
| `TokenType` | `#TK_EOF`, `#TK_Data`, `#TK_VariableBegin`/`End`, `#TK_BlockBegin`/`End`, `#TK_Name`, `#TK_Keyword`, `#TK_String`, `#TK_Integer`, `#TK_Float`, `#TK_Operator`, `#TK_Assign`, `#TK_Pipe`, `#TK_Dot`, `#TK_Comma`, `#TK_LParen`/`RParen`, `#TK_LBracket`/`RBracket`, `#TK_Tilde` |
| `NodeType` | `#NODE_Template`, `#NODE_Text`, `#NODE_Output`, `#NODE_Literal`, `#NODE_Variable`, `#NODE_BinaryOp`, `#NODE_UnaryOp`, `#NODE_Compare`, `#NODE_Filter`, `#NODE_GetAttr`, `#NODE_GetItem`, `#NODE_If`, `#NODE_For`, `#NODE_Set`, `#NODE_Block`, `#NODE_Extends`, `#NODE_Include`, `#NODE_Macro`, `#NODE_Call`, `#NODE_ListLiteral` |
| `ErrorCode` | `#ERR_None`, `#ERR_Syntax`, `#ERR_Render`, `#ERR_Undefined`, `#ERR_Type`, `#ERR_Filter`, `#ERR_Loader`, `#ERR_Inheritance`, `#ERR_Internal` |

Also defines `#JINJA_VERSION$` and `#JINJA_MAX_RECURSION`.

#### Error.pbi — `DeclareModule JinjaError`

Global error state. The first error wins; subsequent errors are silently dropped until
`ClearError()` is called.

| Procedure | Description |
|-----------|-------------|
| `SetError(code, message, lineNumber, templateName)` | Record an error |
| `HasError()` | Returns `#True` if an error is active |
| `ClearError()` | Reset error state |
| `GetErrorMessage()` | Error message string |
| `GetErrorCode()` | ErrorCode enum value |
| `GetErrorLine()` | Line number of error |
| `GetErrorTemplate()` | Template name where error occurred |
| `FormatError()` | Human-readable "ErrorType: message (in template) at line N" |

#### Variant.pbi — `DeclareModule JinjaVariant`

The `JinjaVariant` structure is the central data type.

```purebasic
Structure JinjaVariant
  VType.i      ; VariantType enum
  IntVal.q     ; Integer / Boolean storage (64-bit)
  DblVal.d     ; Double storage
  StrVal.s     ; String / Markup storage
  *ListPtr     ; Pointer to VariantListWrapper (when VType = #VT_List)
  *MapPtr      ; Pointer to VariantMapWrapper (when VType = #VT_Map)
EndStructure
```

List and Map variants point to heap-allocated wrapper structures containing PureBasic
`List` and `Map` respectively. These must be freed with `FreeVariant()`.

**Constructors** — all write into a caller-provided `*out.JinjaVariant`:

| Procedure | Output |
|-----------|--------|
| `NullVariant(*out)` | `#VT_Null` |
| `BoolVariant(*out, value.i)` | `#VT_Boolean` |
| `IntVariant(*out, value.q)` | `#VT_Integer` |
| `DblVariant(*out, value.d)` | `#VT_Double` |
| `StrVariant(*out, value.s)` | `#VT_String` |
| `MarkupVariant(*out, value.s)` | `#VT_Markup` (bypasses auto-escape) |
| `NewListVariant(*out)` | `#VT_List` (allocates list wrapper) |
| `NewMapVariant(*out)` | `#VT_Map` (allocates map wrapper) |

**Conversions:**
`ToString(*v)`, `ToDouble(*v)`, `ToInteger(*v)`, `IsTruthy(*v)`

**Comparison:**
`VariantsEqual(*a, *b)`, `CompareVariants(*a, *b)` (returns -1/0/1)

**Memory:**
`CopyVariant(*dst, *src)` (deep copy), `FreeVariant(*v)`, `FreeVariantList(*ptr)`,
`FreeVariantMap(*ptr)`

**List helpers:**
`VListSize(*v)`, `VListGet(*v, index, *out)`, `VListAdd(*v, *item)`

**Map helpers:**
`VMapGet(*v, key, *out)`, `VMapSet(*v, key, *item)`, `VMapHasKey(*v, key)`,
`VMapSize(*v)`

---

### Lexer

#### Token.pbi — `DeclareModule JinjaToken`

```purebasic
Structure Token
  Type.i          ; TokenType enum
  Value.s         ; Token text
  LineNumber.i    ; 1-based line
  ColumnNumber.i  ; 1-based column
EndStructure
```

`TokenName(tokenType)` returns a debug string for a token type.

#### Lexer.pbi — `DeclareModule JinjaLexer`

```purebasic
Declare Tokenize(input.s, List tokens.JinjaToken::Token())
```

Fills `tokens()` with all tokens from `input`. Operates in two modes:

- **Outside block**: accumulates raw text into `#TK_Data` tokens; watches for `{{`, `{%`,
  and `{#` delimiters.
- **Inside block**: scans identifiers, keywords, operators, string literals, and numbers.
  Comments (`{# ... #}`) are discarded entirely — no token is emitted.

Keywords are detected by looking up the identifier in a module-global map
(`gKeywords`). All other identifiers become `#TK_Name`.

---

### Parser

#### ASTNode.pbi — `DeclareModule JinjaAST`

```purebasic
Structure ASTNode
  NodeType.i          ; NodeType enum
  LineNumber.i
  StringVal.s         ; text content, variable name, operator, filter name, block name
  StringVal2.s        ; second string (macro param CSV)
  IntVal.q            ; literal sub-type, boolean storage
  DblVal.d            ; literal double
  *Left.ASTNode       ; left operand, condition, expression
  *Right.ASTNode      ; right operand, index expression
  *Body.ASTNode       ; first child in body linked list
  *ElseBody.ASTNode   ; first child in else body linked list
  *Next.ASTNode       ; next sibling
  *Args.ASTNode       ; first argument (filters, calls, list literals)
  *ElseIfList.ElseIfClause
EndStructure
```

Children are singly-linked via `*Next`. The `Body`, `ElseBody`, and `Args` fields are all
heads of `*Next`-linked lists.

**Constructors** — one per node type, e.g.:
`NewTextNode(text, line)`, `NewOutputNode(*expr, line)`, `NewIfNode(*cond, line)`,
`NewForNode(varName, *iterable, line)`, `NewFilterNode(*expr, filterName, line)`,
`NewBinaryOpNode(*left, op, *right, line)`, etc.

**Tree helpers:**
`AddChild(*parent, *child)`, `AddElseChild(*parent, *child)`, `AddArg(*parent, *arg)`,
`AddElseIf(*ifNode, *cond)` → `*ElseIfClause`, `AddElseIfBody(*clause, *child)`,
`AddMacroParam(*macroNode, paramName)`

**Memory:** `FreeAST(*node)` — recursively frees the entire subtree.

#### Parser.pbi — `DeclareModule JinjaParser`

```purebasic
Declare.i Parse(List tokens.JinjaToken::Token())
```

Returns a pointer to the root `#NODE_Template` node. On error, `JinjaError::HasError()`
will be true.

The parser copies the token list into a module-global array (`gTokens`) for random-access
look-ahead. Expression precedence (lowest to highest):

```
or -> and -> not -> comparison/in/is -> additive(+,-,~) ->
multiplicative(*,/,//,%,**) -> unary(-,+) -> postfix(.,[].|,()) -> primary
```

Inline ternary (`value if condition else default`) is handled at the top of
`ParseExpression()` by detecting the `if` keyword after parsing the value.

---

### Renderer

#### Context.pbi — `DeclareModule JinjaContext`

```purebasic
Structure ScopeLevel
  Map Variables.JinjaVariant::JinjaVariant()
EndStructure

Structure JinjaContext
  List Scopes.ScopeLevel()   ; last element = innermost scope
EndStructure
```

| Procedure | Description |
|-----------|-------------|
| `CreateContext()` | Allocate context with one global scope |
| `FreeContext(*ctx)` | Free all variants in all scopes, then structure |
| `PushScope(*ctx)` | Add a new scope (for-loop, macro body) |
| `PopScope(*ctx)` | Remove innermost scope, freeing its variants |
| `SetVariable(*ctx, key, *value)` | Set in innermost scope |
| `GetVariable(*ctx, key, *out)` | Search innermost to outermost; returns `#True` if found |
| `HasVariable(*ctx, key)` | Returns `#True` if key exists in any scope |
| `SetGlobalVariable(*ctx, key, *value)` | Set in outermost (global) scope |
| `InitFromMap(*ctx, Map variables())` | Populate global scope from a map |
| `ScopeDepth(*ctx)` | Number of active scopes |

#### Renderer.pbi — `DeclareModule JinjaRenderer`

```purebasic
Declare.s Render(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode,
                 Map variables.JinjaVariant::JinjaVariant())

Declare.s RenderWithContext(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode,
                            *ctx.JinjaContext::JinjaContext)
```

`Render()` creates a fresh context, calls `InitFromMap()`, renders, then frees the context.
`RenderWithContext()` renders into an existing context (used for `{% include %}`).

Internally `RenderNode()` dispatches on `*node\NodeType`. `EvaluateExpression()` dispatches
on the same field and writes its result into a caller-supplied `JinjaVariant`.

**Loop variables** — for each iteration of `{% for %}`, the renderer creates a `#VT_Map`
variant named `loop` containing: `index` (1-based), `index0` (0-based), `first`, `last`,
`length`, `revindex`, `revindex0`.

**Auto-escape** — `AutoEscape()` checks `*env\Autoescape`; if true it calls
`JinjaMarkup::EscapeHTML()` on the string value. `#VT_Markup` variants bypass escaping
regardless of the environment setting.

**Built-in function** — `range(stop)` / `range(start, stop)` / `range(start, stop, step)`
is handled inside `EvaluateCall()`. Additional built-in functions can be added to that
`Select` block.

---

### Environment

#### MarkupSafe.pbi — `DeclareModule JinjaMarkup`

| Procedure | Description |
|-----------|-------------|
| `EscapeHTML(input.s)` | Replaces `& < > " '` with HTML entities (in that order) |
| `IsMarkup(*v)` | Returns `#True` if `*v\VType = #VT_Markup` |

#### Filters.pbi — `DeclareModule JinjaFilters`

All filter procedures share the signature:

```purebasic
Procedure FilterXxx(*value.JinjaVariant::JinjaVariant,
                    *args.JinjaVariant::JinjaVariant,
                    argCount.i,
                    *result.JinjaVariant::JinjaVariant)
```

`*args` is a flat array of `JinjaVariant` structs; use the internal `GetArg(*args, index,
argCount, *out)` helper to retrieve arguments by position.

`RegisterAll(Map filters.i())` populates a filter map with all built-in filters. It is
called automatically by `JinjaEnv::CreateEnvironment()`.

#### Loader.pbi — `DeclareModule JinjaLoader`

```purebasic
Structure TemplateLoader
  LoaderType.i             ; #LOADER_FileSystem or #LOADER_Dict
  BasePath.s               ; FileSystem: base directory
  Map Templates.s()        ; Dict: name -> source string
EndStructure
```

| Procedure | Description |
|-----------|-------------|
| `CreateFileSystemLoader(basePath)` | Load templates from disk |
| `CreateDictLoader()` | Load templates from an in-memory string map |
| `DictLoaderAdd(*loader, name, source)` | Add a template string to a dict loader |
| `LoadTemplate(*loader, name)` | Returns source string, sets error on failure |
| `TemplateExists(*loader, name)` | Returns `#True` if the template can be found |
| `FreeLoader(*loader)` | Free the loader structure |

The filesystem loader reads files as UTF-8 using `ReadString(file, #PB_UTF8 | #PB_File_IgnoreEOL)`.

#### Environment.pbi — `DeclareModule JinjaEnv`

```purebasic
Structure JinjaEnvironment
  Autoescape.i                ; #True (default) to HTML-escape all output
  TrimBlocks.i                ; reserved; not yet implemented
  LStripBlocks.i              ; reserved; not yet implemented
  Map Filters.i()             ; filter name -> procedure address
  *Loader.JinjaLoader::TemplateLoader
  Map TemplateCache.s()       ; reserved for future caching
  Map MacroDefs.i()           ; macro name -> *ASTNode (populated at render time)
EndStructure
```

| Procedure | Description |
|-----------|-------------|
| `CreateEnvironment()` | Allocate environment, register all built-in filters, autoescape on |
| `FreeEnvironment(*env)` | Free loader and structure |
| `RegisterFilter(*env, name, *filterProc)` | Add or override a filter |
| `GetFilter(*env, name)` | Returns procedure address or `#Null` |
| `HasFilter(*env, name)` | Returns `#True` if filter is registered |
| `SetLoader(*env, *loader)` | Attach a loader (frees old one if present) |
| `SetTemplatePath(*env, path)` | Shortcut: creates a FileSystemLoader at `path` |
| `RenderString(*env, templateStr, Map variables())` | Tokenize, parse, and render a template string; returns the rendered output or `"[Error] ..."` on failure |
| `RenderTemplate(*env, templateName, Map variables())` | Load a template by name via the configured loader, then call `RenderString()` |

---

### Inheritance

#### ExtendsResolver.pbi — `DeclareModule JinjaExtends`

```purebasic
Declare.i Resolve(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode)
```

If the AST has no `#NODE_Extends` child, it is returned unchanged.

Otherwise:
1. Load and parse the parent template (recursively resolving multi-level inheritance).
2. Collect all `#NODE_Block` nodes from the child template into a name→pointer map.
3. Clone the parent AST, replacing each parent block with the child's override (if any) or
   keeping the parent's default body.
4. Return the merged root `#NODE_Template`.

`super()` is noted as a design goal but the current implementation does not produce the
parent block's content for `{{ super() }}` calls; that field (`parentBlockContent`) is
populated but not yet exposed to the renderer.

---

## Quick Start

### Including PureJinja

```purebasic
EnableExplicit
XIncludeFile "path/to/PureJinja.pbi"
```

All modules are auto-included in dependency order. No further includes are needed.

### Rendering a Template from a String

`JinjaEnv::RenderString()` is the recommended API. It handles tokenizing, parsing, and
rendering internally, and returns the rendered string (or `"[Error] ..."` on failure).

```purebasic
EnableExplicit
XIncludeFile "../PureJinja.pbi"

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

### Low-level API (direct pipeline)

If you need direct control over each pipeline stage — for example to reuse a parsed AST
or inject a pre-built context — call the pipeline steps individually:

```purebasic
EnableExplicit
XIncludeFile "../PureJinja.pbi"

Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()

Protected NewList tokens.JinjaToken::Token()
JinjaLexer::Tokenize("Hello, {{ name }}!", tokens())

Protected *ast.JinjaAST::ASTNode = JinjaParser::Parse(tokens())

Protected NewMap vars.JinjaVariant::JinjaVariant()
JinjaVariant::StrVariant(@vars("name"), "World")

Protected result.s = JinjaRenderer::Render(*env, *ast, vars())
If JinjaError::HasError()
  result = "[Error] " + JinjaError::FormatError()
  JinjaError::ClearError()
EndIf

JinjaAST::FreeAST(*ast)
JinjaEnv::FreeEnvironment(*env)
ForEach vars()
  JinjaVariant::FreeVariant(@vars())
Next
```

### Loading Templates from the File System

`JinjaEnv::RenderTemplate()` loads and renders in one call:

```purebasic
Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
JinjaEnv::SetTemplatePath(*env, "templates/")

Protected NewMap vars.JinjaVariant::JinjaVariant()
JinjaVariant::StrVariant(@vars("title"), "Home")

Protected result.s = JinjaEnv::RenderTemplate(*env, "index.html", vars())
Debug result

JinjaEnv::FreeEnvironment(*env)
ForEach vars()
  JinjaVariant::FreeVariant(@vars())
Next
```

### Using Filters

Filters are applied in the template using the `|` operator:

```html
{{ name|upper }}
{{ description|truncate(100) }}
{{ price|round(2) }}
{{ items|join(", ") }}
{{ user_input|escape }}
{{ html_content|safe }}
```

Chaining works left to right:

```html
{{ name|trim|title }}
```

### Control Flow

```html
{% if user.is_admin %}
  <a href="/admin">Admin</a>
{% elif user.is_moderator %}
  <a href="/mod">Moderator</a>
{% else %}
  <span>Guest</span>
{% endif %}

{% for item in items %}
  <li>{{ loop.index }}. {{ item.name }}</li>
{% else %}
  <li>No items found.</li>
{% endfor %}

{% set total = price * quantity %}
Total: {{ total }}
```

### Template Inheritance

Base template (`templates/base.html`):

```html
<!DOCTYPE html>
<html>
<head><title>{% block title %}Default Title{% endblock %}</title></head>
<body>
{% block content %}{% endblock %}
</body>
</html>
```

Child template (`templates/page.html`):

```html
{% extends "base.html" %}

{% block title %}My Page{% endblock %}

{% block content %}
<h1>Hello, {{ name }}!</h1>
{% endblock %}
```

Rendering the child template:

```purebasic
Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
JinjaEnv::SetTemplatePath(*env, "templates/")

Protected NewMap vars.JinjaVariant::JinjaVariant()
JinjaVariant::StrVariant(@vars("name"), "World")

Protected result.s = JinjaEnv::RenderTemplate(*env, "page.html", vars())
Debug result

JinjaEnv::FreeEnvironment(*env)
ForEach vars()
  JinjaVariant::FreeVariant(@vars())
Next
```

Note: `RenderTemplate()` does not automatically resolve template inheritance. If the child
template uses `{% extends %}`, use the low-level pipeline and call
`JinjaExtends::Resolve(*env, *ast)` between parse and render (see Low-level API above).

---

## Supported Features

### Phase 0 — Foundation

- `JinjaVariant` tagged union type: Null, Boolean, Integer, Double, String, Markup, List, Map
- Deep copy (`CopyVariant`), deep free (`FreeVariant`)
- Conversions: `ToString`, `ToDouble`, `ToInteger`, `IsTruthy`
- Comparison: `VariantsEqual`, `CompareVariants`
- List helpers: `VListGet`, `VListAdd`, `VListSize`
- Map helpers: `VMapGet`, `VMapSet`, `VMapHasKey`, `VMapSize`
- Global error state with error codes and line-number reporting

### Phase 1 — Lexer

- Raw text outside blocks → `#TK_Data`
- Variable blocks `{{ ... }}` → `#TK_VariableBegin`/`End`
- Statement blocks `{% ... %}` → `#TK_BlockBegin`/`End`
- Comments `{# ... #}` → silently discarded
- String literals with escape sequences (`\n`, `\t`, `\"`, `\'`, `\\`)
- Integer and float number literals
- Keyword recognition: `if elif else endif for endfor in extends block endblock include set macro endmacro call endcall with endwith and or not is true false none raw endraw`
- All operators: `+ - * / // % ** ~ == != < > <= >=`
- Punctuation: `( ) [ ] , : . | =`
- Line and column tracking for error reporting

### Phase 2 — Parser

- Full expression precedence (9 levels)
- Inline ternary: `value if condition else default`
- All literal types: string, integer, float, boolean (`true`/`false`), `none`
- Variable references
- Binary operators: `+ - * / // % ** ~`
- Unary operators: `-` (negate), `not`
- Comparison operators: `== != < > <= >=`
- Membership: `in`, `not in`
- Identity tests: `is`, `is not`
- Attribute access: `obj.attr`
- Item access: `obj["key"]` or `obj[index]`
- Filter application: `value|filter` and `value|filter(arg1, arg2)`
- Function/macro calls: `name(args)`
- List literals: `[a, b, c]`
- Statement parsing: `if/elif/else/endif`, `for/else/endfor`, `set`, `block/endblock`,
  `extends`, `include`, `macro/endmacro`, `call/endcall`

### Phase 3 — Renderer

- Variable interpolation: `{{ var }}`
- Dot access: `{{ obj.key }}`
- Bracket access: `{{ obj["key"] }}` and `{{ list[0] }}`
- All arithmetic, comparison, and logical operators
- `{% if %}` / `{% elif %}` / `{% else %}` / `{% endif %}`
- `{% for item in list %}` with `loop.index`, `loop.index0`, `loop.first`, `loop.last`,
  `loop.length`, `loop.revindex`, `loop.revindex0`
- `{% for ... %}{% else %}{% endfor %}` (empty-iterable else clause)
- `{% set var = expr %}`
- Scope isolation per for-loop iteration
- `is` / `is not` tests: `none`, `defined`, `undefined`, `even`, `odd`, `number`, `string`
- Built-in function: `range(stop)` / `range(start, stop)` / `range(start, stop, step)`
- Missing variable → empty string (no error)

### Phase 4 — Environment / Filters / Loaders

- Auto-escaping HTML: `& < > " '`
- `#VT_Markup` passthrough (no double-escaping)
- FileSystemLoader (reads UTF-8 files)
- DictLoader (in-memory string map)
- Custom filter registration via `JinjaEnv::RegisterFilter()`
- All 25 built-in filters (see table below)

### Phase 5 — Template Inheritance and Include

- `{% extends "parent.html" %}` — template inheritance
- `{% block name %}...{% endblock %}` — overridable blocks
- Multi-level inheritance (grandchild extends child extends base)
- `{% include "partial.html" %}` — inline another template with shared context

### Built-in Filters

| Filter | Alias | Description |
|--------|-------|-------------|
| `upper` | | Convert to uppercase |
| `lower` | | Convert to lowercase |
| `title` | | Title-case every word |
| `capitalize` | | Uppercase first character, lowercase the rest |
| `trim` | | Strip leading and trailing whitespace |
| `length` | `count` | String length, or list/map size |
| `default(value)` | `d` | Return default if null or empty string |
| `int` | | Convert to integer |
| `float` | | Convert to double |
| `string` | | Convert to string |
| `join(sep)` | | Join list items with separator |
| `replace(old, new)` | | Replace substring |
| `first` | | First list item or first character |
| `last` | | Last list item or last character |
| `reverse` | | Reverse a list or string |
| `sort` | | Sort a list (bubble sort, numeric comparison) |
| `escape` | `e` | HTML-escape and mark as Markup |
| `safe` | | Mark as Markup (bypass auto-escape) |
| `abs` | | Absolute value |
| `round(precision)` | | Round to N decimal places |
| `list` | | Convert string to list of characters; pass lists through |
| `batch(n)` | | Split list into sub-lists of N items |
| `wordcount` | | Count words in a string |
| `truncate(n)` | | Truncate string to N characters, appending `...` |
| `striptags` | | Remove HTML tags |

---

## Adding Custom Filters

A custom filter is a PureBasic procedure that matches the `ProtoFilter` signature.

```purebasic
; A filter that repeats a string N times: {{ value|repeat(3) }}
Procedure FilterRepeat(*value.JinjaVariant::JinjaVariant,
                       *args.JinjaVariant::JinjaVariant,
                       argCount.i,
                       *result.JinjaVariant::JinjaVariant)
  Protected s.s = JinjaVariant::ToString(*value)
  Protected times.i = 1

  ; Read first argument (the repeat count)
  If argCount >= 1
    Protected argV.JinjaVariant::JinjaVariant
    Protected *argSlot.JinjaVariant::JinjaVariant = *args + (0 * SizeOf(JinjaVariant::JinjaVariant))
    JinjaVariant::CopyVariant(@argV, *argSlot)
    times = JinjaVariant::ToInteger(@argV)
    JinjaVariant::FreeVariant(@argV)
  EndIf

  Protected output.s = ""
  Protected i.i
  For i = 1 To times
    output + s
  Next
  JinjaVariant::StrVariant(*result, output)
EndProcedure

; Register the filter before rendering
Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
JinjaEnv::RegisterFilter(*env, "repeat", @FilterRepeat())
```

Use in a template:

```html
{{ "abc"|repeat(3) }}   -> abcabcabc
```

Rules:
- Always write the result via one of the `JinjaVariant` constructors into `*result`.
  Never leave `*result` uninitialised.
- Free any `JinjaVariant` values you copy out of `*args` with `JinjaVariant::FreeVariant()`.
- Do not call `FreeVariant(*result)` before writing to it — it is uninitialised on entry.
- Do not call `FreeVariant(*value)` — it is owned by the renderer.
- Do not set errors for missing arguments; instead use a sensible default.

---

## Running Tests

### Compile and Run

```bash
# From the pure_jinja/ directory
pbcompiler -cl Tests/TestRunner.pb -o Tests/TestRunner
./Tests/TestRunner
```

The `-cl` flag compiles a console application. On Windows, omit `./` and add `.exe`.

### Expected Output

```
=== PureJinja Test Suite v0.8.0 ===

[PASS] NullVariant type
[PASS] BoolVariant true
...
=== Results ===
Passed: N/N
ALL TESTS PASSED
```

### Adding a New Test

1. Open (or create) the relevant `Tests/TestXxx.pbi` file.
2. Write a procedure `RunXxxTests()` that calls `AssertEqual()`, `AssertTrue()`, or
   `AssertFalse()` from the test framework.
3. Include the file in `Tests/TestRunner.pb` with `XIncludeFile "TestXxx.pbi"`.
4. Call `RunXxxTests()` in the main body of `TestRunner.pb`.

Example test in `Tests/TestLexer.pbi`:

```purebasic
Procedure RunLexerTests()
  PrintN("--- Lexer Tests ---")
  Protected NewList tokens.JinjaToken::Token()

  JinjaLexer::Tokenize("Hello {{ name }}!", tokens())
  AssertEqual(Str(ListSize(tokens())), "5", "Lexer: token count for Hello {{ name }}!")
  ; Tokens: TK_Data, TK_VariableBegin, TK_Name, TK_VariableEnd, TK_EOF

  JinjaError::ClearError()
  JinjaLexer::Tokenize("{# ignored #}text", tokens())
  FirstElement(tokens())
  AssertEqual(tokens()\Value, "text", "Lexer: comment discarded")
EndProcedure
```

---

## Known Limitations

The following features are deferred (Tier 3 from the feasibility study) and are not yet
implemented:

**Whitespace control** — The `-` strip markers (`{%- -%}`, `{{- -}}`) and the
`trim_blocks`/`lstrip_blocks` environment flags are defined in `JinjaEnvironment` but not
processed by the lexer or renderer.

**`{% raw %}` blocks** — Raw block parsing is not implemented. The lexer recognises `raw`
and `endraw` as keywords, but the renderer does not handle them.

**Dict literals** — `{"key": "value"}` syntax in expressions is not parsed. Use a
`#VT_Map` variant in application code instead.

**`super()` in blocks** — The `ExtendsResolver` populates a `parentBlockContent` map
during merging, but `super()` calls in child blocks are not resolved to the parent's
content at render time.

**Higher-order filters** — `groupby`, `map`, `select`, `reject`, `selectattr`,
`rejectattr`, `unique`, `dictsort`, `tojson`, `urlencode`, `indent`, `wordwrap`,
`filesizeformat`, `center` are not implemented.

**`{% from ... import %}` / `{% import %}`** — Not implemented.

**Recursive loops** — `{% for ... recursive %}` is not implemented.

**`namespace()` objects** — Cross-scope variable assignment via `namespace` is not
implemented.

**Global functions** — `dict()`, `cycler()`, `joiner()`, `lipsum()` are not implemented.
`range()` is implemented as a built-in function via `EvaluateCall()`.

---

## Version History

**v0.0** — Initial project setup, feasibility study, test templates copied from Xojo
JinjaX reference implementation.

**v0.6** — Phase 0–5 complete. 5,057 lines across 17 files. All 38 variant unit tests
pass. Compilation clean with PureBasic 6.30 on macOS.

**v0.7** — Comprehensive test suite added. Unit tests expanded across all modules
(lexer, parser, renderer, filters, inheritance, environment).

**v0.8** — `JinjaEnv::RenderString()` and `RenderTemplate()` fixed to complete the
end-to-end rendering pipeline. The circular dependency between `Environment.pbi` and
`Renderer.pbi` is resolved via a runtime callback: `Renderer.pbi` calls
`JinjaEnv::RegisterRenderer(@Render())` at load time, allowing `RenderString()` to
invoke the renderer without a compile-time circular include. Acceptance tests added
against real HTML templates.

**v0.9** — Full acceptance test coverage for all 55 templates. Inheritance tests
(43 tests) validate extends/block for single-level, multi-block, variables-in-blocks,
3-level grandchild chains, and logic-in-blocks. Include tests verify partial loading
via DictLoader. Real-world tests cover product lists, user profiles, email templates,
table reports with loop.index, navigation with active-URL comparison, and error pages
with default() filters. Total: 466/466 tests passing, 7,976 lines compiled.

**v1.0** — Three major features added:

1. **Auto-resolve inheritance**: `RenderString()` and `RenderTemplate()` now auto-detect
   `{% extends %}` and resolve inheritance before rendering (no manual
   `JinjaExtends::Resolve()` needed). Uses same runtime callback pattern as renderer.

2. **Whitespace control**: Strip markers `{%-`, `-%}`, `{{-`, `-}}`, `{#-`, `-#}` remove
   adjacent whitespace from text nodes. Handled entirely in the Lexer via a post-processing
   pass that strips leading/trailing whitespace from TK_Data tokens.

3. **Raw blocks**: `{% raw %}...{% endraw %}` outputs content literally without Jinja
   processing. Handled in the Lexer — content between raw/endraw becomes a single TK_Data
   token. No Parser or Renderer changes needed.

Total: 497/497 tests passing, 8,583 lines compiled, 27 source files.
