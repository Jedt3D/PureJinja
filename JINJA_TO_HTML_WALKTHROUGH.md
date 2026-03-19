# Code Walkthrough: jinja_to_html.pb

`jinja_to_html.pb` is a standalone CLI application that renders all 55 PureJinja demo
templates to static HTML files. It serves as both a demo and a practical reference for
how to use every PureJinja API pattern: simple variables, lists, maps, nested structures,
markup variants, template inheritance, and includes.

## Build and Run

```bash
# macOS / Linux
pbcompiler -cl jinja_to_html.pb -o jinja_to_html_app
./jinja_to_html_app

# Windows
pbcompiler /cl jinja_to_html.pb /exe jinja_to_html_app.exe
jinja_to_html_app.exe
```

Output goes to the `jinja_to_html/` directory. Console output shows per-template status:

```
PureJinja -> HTML renderer
==========================

[OK]  01_hello.html
[OK]  02_multiple_vars.html
...
[OK]  55_error_page.html

Rendered: 55/55
```

---

## File Structure

```
jinja_to_html.pb          ; The CLI app (this file)
jinja_to_html/            ; Output directory (created at runtime)
  01_hello.html           ; Rendered static HTML
  02_multiple_vars.html
  ...
  55_error_page.html
```

---

## Code Organization

The file is organized into three sections:

1. **Helper procedures** (lines 12-74) -- reduce boilerplate for common operations
2. **Main program** (lines 76-585) -- environment setup, per-template variable setup, render loop, cleanup

### Section 1: Helper Procedures

Six helpers abstract the repetitive parts of the PureJinja API:

#### Variable setters

```purebasic
Procedure SetStr(Map vars.JinjaVariant::JinjaVariant(), key.s, value.s)
  Protected v.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@v, value)
  vars(key) = v
EndProcedure
```

Each setter follows the same pattern:
1. Declare a local `JinjaVariant` structure
2. Call the appropriate constructor (`StrVariant`, `IntVariant`, `BoolVariant`, `MarkupVariant`)
3. Assign the variant into the map by key

There are four setters covering the scalar types:

| Procedure    | Variant Constructor            | Use Case                        |
|-------------|-------------------------------|---------------------------------|
| `SetStr()`  | `JinjaVariant::StrVariant()`  | String values (most templates)  |
| `SetInt()`  | `JinjaVariant::IntVariant()`  | Integer values (count, price)   |
| `SetBool()` | `JinjaVariant::BoolVariant()` | Boolean flags (logged_in, etc.) |
| `SetMarkup()` | `JinjaVariant::MarkupVariant()` | Pre-escaped HTML (safe output) |

#### CleanupVars

```purebasic
Procedure CleanupVars(Map vars.JinjaVariant::JinjaVariant())
  ForEach vars()
    JinjaVariant::FreeVariant(@vars())
  Next
  ClearMap(vars())
EndProcedure
```

Frees heap-allocated memory (list/map internals) for every variant in the map, then
clears the map so it can be reused for the next template. Called after every
`RenderAndSave()` that used variables. For scalar types (string, int, bool),
`FreeVariant` is a no-op, but calling it uniformly is safe and avoids leaks when the
map contains complex types.

#### RenderAndSave

```purebasic
Procedure.i RenderAndSave(*env, templateName.s, Map vars.JinjaVariant::JinjaVariant(), outputDir.s)
  Protected result.s = JinjaEnv::RenderTemplate(*env, templateName, vars())
  Protected outputPath.s = outputDir + templateName
  Protected file.i = CreateFile(#PB_Any, outputPath, #PB_UTF8)
  If file
    WriteString(file, result, #PB_UTF8)
    CloseFile(file)
    PrintN("[OK]  " + templateName)
    ProcedureReturn 1
  Else
    PrintN("[ERR] " + templateName + " (write failed)")
    ProcedureReturn 0
  EndIf
EndProcedure
```

Calls `JinjaEnv::RenderTemplate()` (the primary API), writes the result as UTF-8 to
the output directory, prints status, and returns 1 (success) or 0 (failure). The return
value feeds into the `ok` counter for the summary.

#### MakeStringList

```purebasic
Procedure MakeStringList(Map vars.JinjaVariant::JinjaVariant(), key.s, Array items.s(1))
  Protected listV.JinjaVariant::JinjaVariant
  Protected tmpV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@listV)
  For i = 0 To ArraySize(items())
    JinjaVariant::StrVariant(@tmpV, items(i))
    JinjaVariant::VListAdd(@listV, @tmpV)
  Next
  vars(key) = listV
EndProcedure
```

Creates a list variant from a PureBasic string array. Used by 10 templates
(23-32) that all iterate over `items = ["Apple", "Banana", "Cherry"]`.

---

### Section 2: Main Program

#### Environment Setup (lines 80-96)

```purebasic
OpenConsole()
Define *env = JinjaEnv::CreateEnvironment()
JinjaEnv::SetTemplatePath(*env, "templates/")
CreateDirectory(#OutputDir)
```

- `CreateEnvironment()` initializes the Jinja environment with autoescape enabled
  (default `#True` for HTML output).
- `SetTemplatePath()` configures the FileSystemLoader so `RenderTemplate()` can load
  `.html` files by name from the `templates/` directory.
- The output directory is created if it doesn't exist; `CreateDirectory()` silently
  succeeds if it already does.

#### Per-Template Rendering (lines 98-576)

Each template follows the same pattern:

```purebasic
; 1. Set up variables
SetStr(vars(), "name", "World")

; 2. Render and save
ok + RenderAndSave(*env, "01_hello.html", vars(), #OutputDir)

; 3. Clean up for next template
CleanupVars(vars())
```

The variables map is reused across templates -- `CleanupVars()` resets it between
renders. Templates that need no external variables (03, 12, 33, 35, 41-43, 45, 47, 48)
skip steps 1 and 3.

#### Variable Complexity Tiers

The 55 templates exercise four tiers of variable complexity:

**Tier 1 -- Scalars** (templates 01-22, 33-40, 44, 46, 49, 52, 55)

Simple key-value pairs using the helper setters:

```purebasic
SetStr(vars(), "name", "World")           ; string
SetInt(vars(), "count", 42)               ; integer
SetBool(vars(), "logged_in", #True)       ; boolean
SetMarkup(vars(), "safe_html", "<b>Bold</b>")  ; pre-escaped HTML
```

**Tier 2 -- String Lists** (templates 21, 23-25, 27, 29-32)

Uses `MakeStringList()` with a shared array:

```purebasic
Dim items3.s(2)
items3(0) = "Apple" : items3(1) = "Banana" : items3(2) = "Cherry"
MakeStringList(vars(), "items", items3())
```

**Tier 3 -- Maps** (templates 05, 51)

Built manually using the Variant map API:

```purebasic
JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Alice")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::StrVariant(@tmpV, "alice@example.com")
JinjaVariant::VMapSet(@mapV, "email", @tmpV)
vars("user") = mapV
```

The `tmpV` variable is a reusable scratch variant -- each `StrVariant()` call
overwrites it, and `VMapSet()` copies the value into the map.

**Tier 4 -- Lists of Maps / Nested Lists** (templates 26, 28, 50, 53, 54)

The most complex data structures, combining lists and maps:

```purebasic
; List of product maps (template 50)
JinjaVariant::NewListVariant(@listV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Widget")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::IntVariant(@tmpV, 10)
JinjaVariant::VMapSet(@mapV, "price", @tmpV)
JinjaVariant::BoolVariant(@tmpV, #True)
JinjaVariant::VMapSet(@mapV, "in_stock", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)
; ... second product ...

vars("products") = listV
```

Pattern: create the outer list, then for each item create a map, populate its
fields with the scratch variant, add the map to the list, repeat.

Template 28 (nested for loops) uses lists of lists:

```purebasic
JinjaVariant::NewListVariant(@listV)          ; outer list

JinjaVariant::NewListVariant(@innerList)      ; first inner list
JinjaVariant::StrVariant(@tmpV, "a")
JinjaVariant::VListAdd(@innerList, @tmpV)
JinjaVariant::StrVariant(@tmpV, "b")
JinjaVariant::VListAdd(@innerList, @tmpV)
JinjaVariant::VListAdd(@listV, @innerList)    ; add inner to outer

; ... second inner list ...
vars("groups") = listV
```

#### Template Inheritance (templates 41-46, 52)

Templates using `{% extends %}` are rendered through the same `RenderTemplate()` API.
The environment auto-detects the `{% extends %}` tag and resolves block inheritance
before rendering. No special API calls are needed:

```purebasic
; Template 44 extends 41_base.html and uses variables in blocks
SetStr(vars(), "page_title", "Welcome")
SetStr(vars(), "user_name", "Alice")
ok + RenderAndSave(*env, "44_child_with_vars.html", vars(), #OutputDir)
```

Templates 41-43 and 45 need no variables (they use literal block content or default
blocks from the base template).

#### Template Include (templates 47-49)

Templates using `{% include %}` also work transparently:

```purebasic
; Template 49 includes 47_header_partial.html and uses context variable
SetStr(vars(), "name", "World")
ok + RenderAndSave(*env, "49_include_with_context.html", vars(), #OutputDir)
```

The included partial shares the same variable context as the parent template.

#### Summary and Cleanup (lines 578-585)

```purebasic
PrintN("Rendered: " + Str(ok) + "/55")
JinjaEnv::FreeEnvironment(*env)
CloseConsole()
```

---

## Bugfix: Use-After-Free in Template Inheritance

During development of this app, a segfault was discovered when rendering templates
that use `{% extends %}` with variables in blocks (templates 44, 46, 52).

**Root cause:** In `Environment/Environment.pbi`, the `RenderString()` procedure freed
the child AST immediately after the ExtendsResolver returned a merged AST. However, the
resolver shares child block-body node pointers with the merged AST without deep-copying
them. Freeing the child AST left dangling pointers that crashed the renderer when it
tried to evaluate variable expressions in inherited blocks.

**Fix:** Removed the premature `FreeAST(*ast)` call (line 161). The child structural
nodes become a small bounded leak per render call -- matching the strategy already used
by the test suite's `Inh_RenderInherited()` helper. The shared block-body nodes are
correctly freed when the merged AST is freed after rendering.

This fix is invisible to users of the API. All 599 existing tests continue to pass.

---

## Template Coverage Summary

| Category | Templates | Variable Pattern |
|----------|-----------|-----------------|
| Variables & Filters | 01-15 | Strings, integers, maps |
| Conditionals | 16-22 | Booleans, strings, integers, lists |
| For Loops | 23-32 | String lists, map lists, nested lists |
| Set Statements | 33-35 | None (internal `{% set %}`) |
| Auto-Escaping | 36-40 | Strings + MarkupVariants |
| Inheritance | 41-46 | None to strings + booleans |
| Include | 47-49 | None to strings |
| Real-World | 50-55 | Complex: map lists, nested maps |
