# PureJinja Quick Start

Get up and running with PureJinja in 5 minutes.

## Prerequisites

- PureBasic 6.x (macOS, Windows, or Linux)
- The `pure_jinja/` directory on your include path

## Step 1: Include the Library

A single include brings in all modules:

```purebasic
EnableExplicit
XIncludeFile "PureJinja.pbi"
```

## Step 2: Hello World

Create an environment, set a variable, and render a template string:

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

`RenderString()` handles tokenizing, parsing, and rendering internally.
Always free the environment and variant map when you are done.

## Step 3: Using Filters

Filters transform values in templates using the `|` operator:

```
{{ name|upper }}              -> WORLD
{{ name|lower }}              -> world
{{ name|title }}              -> World
{{ "  hello  "|trim }}        -> hello
{{ items|length }}            -> 3
{{ price|round(2) }}          -> 19.99
{{ missing_var|default("N/A") }}  -> N/A
```

Filters can be chained left to right:

```
{{ "  hello world  "|trim|title }}  -> Hello World
```

PureJinja ships with 35 built-in filters. See DEVELOPER_GUIDE.md for the full list.

## Step 4: Control Flow

**Conditionals:**

```
{% if user_role == "admin" %}
  <p>Welcome, administrator.</p>
{% elif user_role == "editor" %}
  <p>Welcome, editor.</p>
{% else %}
  <p>Welcome, guest.</p>
{% endif %}
```

**Loops:**

```
{% for item in items %}
  <li>{{ loop.index }}. {{ item }}</li>
{% else %}
  <li>No items found.</li>
{% endfor %}
```

The `loop` variable provides: `index` (1-based), `index0` (0-based), `first`,
`last`, `length`, `revindex`, `revindex0`.

**Passing a list variable from PureBasic:**

```purebasic
Protected listVar.JinjaVariant::JinjaVariant
JinjaVariant::NewListVariant(@listVar)
Protected item.JinjaVariant::JinjaVariant
JinjaVariant::StrVariant(@item, "Apple")
JinjaVariant::VListAdd(@listVar, @item)
JinjaVariant::FreeVariant(@item)
JinjaVariant::StrVariant(@item, "Banana")
JinjaVariant::VListAdd(@listVar, @item)
JinjaVariant::FreeVariant(@item)
JinjaVariant::StrVariant(@item, "Cherry")
JinjaVariant::VListAdd(@listVar, @item)
JinjaVariant::FreeVariant(@item)
JinjaVariant::CopyVariant(@vars("fruits"), @listVar)
JinjaVariant::FreeVariant(@listVar)
```

Then in the template: `{% for fruit in fruits %}{{ fruit }}{% endfor %}`

## Step 5: Template Files with FileSystemLoader

Load and render templates from disk using `RenderTemplate()`:

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

`SetTemplatePath()` creates a FileSystemLoader pointed at the given directory.
`RenderTemplate()` loads the named file, tokenizes, parses, and renders it.

## Step 6: Template Inheritance

Create a base template (`templates/base.html`):

```html
<!DOCTYPE html>
<html>
<head><title>{% block title %}Default Title{% endblock %}</title></head>
<body>
{% block content %}{% endblock %}
</body>
</html>
```

Create a child template (`templates/page.html`):

```html
{% extends "base.html" %}
{% block title %}My Page{% endblock %}
{% block content %}
<h1>Hello, {{ name }}!</h1>
{% endblock %}
```

Render the child -- inheritance is resolved automatically:

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

The output will be the base template with the child's block overrides filled in.

## Next Steps

- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) -- Full API reference, module documentation, custom filters, and architecture details.
- [FEASIBILITY_STUDY.md](FEASIBILITY_STUDY.md) -- Original design analysis and feature tier breakdown.
- [CHANGELOG.md](CHANGELOG.md) -- Complete version history.
