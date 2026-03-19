# PureJinja Architecture

This document is a technical deep-dive into the design and implementation of PureJinja,
a Jinja template engine written in PureBasic.

---

## Pipeline Overview

PureJinja processes templates through a 4-stage pipeline:

```
Template String
    |
    v
  Lexer (Tokenize)
    |
    v
  Token List
    |
    v
  Parser (Parse)
    |
    v
  AST (Abstract Syntax Tree)
    |
    v
  Renderer (Render)
    |
    v
  Output String
```

Each stage is independent and testable in isolation. An optional **ExtendsResolver** stage
sits between the Parser and Renderer to handle template inheritance. It is auto-invoked by
`RenderString()` and `RenderTemplate()`, so callers do not need to manage it explicitly.

---

## Module Dependency Diagram

```
PureJinja.pbi  (master include)
|
+-- Core/Constants.pbi          (enumerations: VariantType, TokenType, NodeType, ErrorCode)
+-- Core/Error.pbi              (global error state; depends on Constants)
+-- Core/Variant.pbi            (JinjaVariant tagged union; depends on Constants, Error)
|
+-- Lexer/Token.pbi             (Token structure + debug name helper)
+-- Lexer/Lexer.pbi             (tokenizer; depends on Token, Constants)
|
+-- Parser/ASTNode.pbi          (ASTNode structure + constructors; depends on Constants)
+-- Parser/Parser.pbi           (recursive descent parser; depends on ASTNode, Token, Lexer, Error)
|
+-- Environment/MarkupSafe.pbi  (HTML escaping; depends on Variant)
+-- Environment/Filters.pbi     (built-in filter procedures; depends on Variant, MarkupSafe)
+-- Environment/Loader.pbi      (FileSystem + Dict loaders; depends on Error)
+-- Environment/Environment.pbi (JinjaEnvironment; depends on all of the above)
|
+-- Renderer/Context.pbi        (scope stack; depends on Variant)
+-- Renderer/Renderer.pbi       (tree-walker; depends on everything above)
|
+-- Inheritance/ExtendsResolver.pbi  (block merging; depends on Renderer, Lexer, Parser)
```

`PureJinja.pbi` includes all files in dependency order. User code only needs to include
`PureJinja.pbi` to access the full engine.

---

## Five Key Design Patterns

### 1. Tagged Union (JinjaVariant)

PureBasic has no dynamic typing. Every template value is a `JinjaVariant` structure with a
`VType` field that selects which storage field is active (`IntVal`, `DblVal`, `StrVal`,
`ListPtr`, `MapPtr`). There are 8 types: Null, Boolean, Integer, Double, String, Markup,
List, and Map. All variant operations dispatch with `Select *v\VType`.

This is the foundation of the type system. Filters, the renderer, and the context all
operate on `JinjaVariant` pointers. Type coercion (e.g., truthiness checks, string
conversion) is handled by utility procedures in `Variant.pbi`.

### 2. Select/Case AST Dispatch

PureBasic has no class inheritance or virtual dispatch. The renderer and expression
evaluator dispatch on `*node\NodeType` using `Select/Case`. All 22 node types share a
single flat `ASTNode` structure; unused fields are zero.

This is the standard pattern for tree-walking interpreters in C-family procedural
languages. It keeps the code straightforward and avoids the need for function pointer
tables or object hierarchies.

### 3. Global Error State

PureBasic has no exceptions. `JinjaError::SetError()` records the first error (code,
message, and line number). All procedures check `JinjaError::HasError()` at the top and
return early if an error has already been set. The caller inspects the error after the
top-level call returns and calls `JinjaError::ClearError()` before the next operation.

This pattern ensures errors propagate cleanly up the call stack without requiring every
function to return an error code.

### 4. Scope Stack

`JinjaContext` is a `List` of `ScopeLevel`, each containing a `Map` of `JinjaVariant`.
`GetVariable()` walks from the innermost scope to the outermost. `PushScope()` and
`PopScope()` manage for-loop iterations and macro calls.

The `namespace()` built-in creates a Map variant that can be modified in-place across scope
boundaries via `SetVariableMapEntry()`. This allows Jinja's `namespace` pattern to work
correctly inside for-loops where normal variable assignment would be scoped.

### 5. Runtime Callbacks (Circular Dependency Resolution)

`Environment.pbi` must compile before `Renderer.pbi` (it declares `JinjaEnvironment`),
yet `RenderString()` in the environment needs to call `JinjaRenderer::Render()`. This
creates a circular dependency.

Solution: `Environment.pbi` declares a `ProtoRenderCallback` prototype and stores a global
`gRenderCallback` procedure pointer. At the bottom of `Renderer.pbi`,
`JinjaEnv::RegisterRenderer(@Render())` installs the callback. The same pattern is used
for `ExtendsResolver` via `RegisterResolver()`.

`PureJinja.pbi` includes files in dependency order so that callbacks are set before any
user code runs.

---

## AST Node Design

There are 22 node types sharing a single flat `ASTNode` structure. Key fields:

- **Identity:** `NodeType`, `LineNumber`
- **Values:** `StringVal`, `StringVal2`, `IntVal`, `DblVal`
- **Tree links:** `*Left`, `*Right`, `*Body`, `*ElseBody`, `*Next`, `*Args`, `*ElseIfList`

Children are singly-linked via `*Next`. The `Body`, `ElseBody`, and `Args` fields are all
heads of `*Next`-linked lists.

The 22 node types are: Template, Text, Output, Literal, Variable, BinaryOp, UnaryOp,
Compare, Filter, GetAttr, GetItem, If, For, Set, Block, Extends, Include, Macro, Call,
ListLiteral, DictLiteral, and Import.

---

## Filter System

All filters share the prototype:

```
ProtoFilter(*value, *args, argCount, *result)
```

The environment stores a `Map` of filter name to procedure address. Filters are called via
the prototype without knowing the callee at compile time. There are 33 built-in filters
registered by `RegisterAll()`, plus 3 aliases (`count`, `d`, `e`).

Custom filters use the same prototype and are registered with `JinjaEnv::RegisterFilter()`.
This makes the filter system fully extensible without modifying engine source code.

---

## Memory Management Patterns

- **Variant ownership:** The renderer owns variant values. Filters must not free `*value`
  (renderer-owned) or `*result` (uninitialized on entry). Filters must free any variants
  they copy from `*args`.

- **AST lifetime:** `FreeAST(*node)` recursively frees the entire subtree. Called after
  rendering is complete.

- **Context cleanup:** `FreeContext(*ctx)` frees all variants in all scopes. `PopScope()`
  frees variants in the removed scope.

- **Deep copy:** `CopyVariant(*dst, *src)` performs deep copy for lists and maps. Required
  when storing variants in new scopes to avoid aliasing bugs.

- **Environment:** `FreeEnvironment(*env)` frees the loader and environment structure. The
  user is responsible for freeing their own variable maps passed into the engine.

All memory is manually managed. There is no garbage collector. The ownership rules above
prevent double-frees and use-after-free in normal operation.
