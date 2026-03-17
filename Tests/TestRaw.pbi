; ============================================================================
; PureJinja - TestRaw.pbi
; Tests for {% raw %}...{% endraw %} block support
; Raw blocks emit their content literally without any Jinja processing.
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Helper: render template string with autoescape OFF
; (named Raw_ to avoid conflicts with other test helpers)
; ---------------------------------------------------------------------------
Procedure.s Raw_Render(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False
  Protected result.s = JinjaEnv::RenderString(*env, templateStr, variables())
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn result
EndProcedure

; ---------------------------------------------------------------------------
Procedure RunRawTests()
  PrintN("--- Raw Block Tests ---")

  Protected NewMap emptyVars.JinjaVariant::JinjaVariant()
  Protected tmpV.JinjaVariant::JinjaVariant

  ; ==========================================================================
  ; Test 1: Variable syntax inside raw block is not interpreted
  ; ==========================================================================
  AssertEqual(Raw_Render("{% raw %}{{ x }}{% endraw %}", emptyVars()),
              "{{ x }}",
              "Raw 01: variable syntax preserved literally")

  ; ==========================================================================
  ; Test 2: Block tag syntax inside raw block is not interpreted
  ; ==========================================================================
  AssertEqual(Raw_Render("{% raw %}{% if true %}yes{% endif %}{% endraw %}", emptyVars()),
              "{% if true %}yes{% endif %}",
              "Raw 02: block tag syntax preserved literally")

  ; ==========================================================================
  ; Test 3: Text before and after raw block is preserved
  ; ==========================================================================
  AssertEqual(Raw_Render("before{% raw %}{{ x }}{% endraw %}after", emptyVars()),
              "before{{ x }}after",
              "Raw 03: text before/after raw block preserved")

  ; ==========================================================================
  ; Test 4: Empty raw block produces empty output
  ; ==========================================================================
  AssertEqual(Raw_Render("{% raw %}{% endraw %}", emptyVars()),
              "",
              "Raw 04: empty raw block produces empty string")

  ; ==========================================================================
  ; Test 5: Mixed — variables outside raw block are still rendered
  ; ==========================================================================
  Protected NewMap vars05.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "a")
  vars05("x") = tmpV
  JinjaVariant::StrVariant(@tmpV, "b")
  vars05("y") = tmpV
  AssertEqual(Raw_Render("{{ x }}{% raw %}literal{% endraw %}{{ y }}", vars05()),
              "aliteralb",
              "Raw 05: variables outside raw block still render")

  ; ==========================================================================
  ; Test 6: Raw block with whitespace variations in endraw tag
  ; ==========================================================================
  AssertEqual(Raw_Render("{% raw %}hello{%endraw%}", emptyVars()),
              "hello",
              "Raw 06: endraw without spaces is recognized")

  ; ==========================================================================
  ; Test 7: Raw block content with curly braces that are not delimiters
  ; ==========================================================================
  AssertEqual(Raw_Render("{% raw %}{ single brace }{% endraw %}", emptyVars()),
              "{ single brace }",
              "Raw 07: single curly braces inside raw block preserved")

  ; ==========================================================================
  ; Test 8: Whitespace variations in opening raw tag
  ; ==========================================================================
  AssertEqual(Raw_Render("{%raw%}{{ x }}{%endraw%}", emptyVars()),
              "{{ x }}",
              "Raw 08: raw without spaces in opening tag recognized")

  PrintN("")

EndProcedure
