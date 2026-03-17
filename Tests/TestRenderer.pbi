; ============================================================================
; PureJinja - TestRenderer.pbi
; Unit tests for the Renderer and Context modules
; Tests the full Lexer -> Parser -> Renderer pipeline
; ============================================================================
EnableExplicit

; --- Helper: render a template string with a variable map (autoescape ON) ---
Procedure.s RendererHelper_RenderString(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  JinjaError::ClearError()
  Protected NewList tokens.JinjaToken::Token()
  JinjaLexer::Tokenize(templateStr, tokens())
  If JinjaError::HasError()
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *ast.JinjaAST::ASTNode = JinjaParser::Parse(tokens())
  If JinjaError::HasError()
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #True
  Protected result.s = JinjaRenderer::Render(*env, *ast, variables())
  JinjaEnv::FreeEnvironment(*env)
  JinjaAST::FreeAST(*ast)
  ProcedureReturn result
EndProcedure

; --- Helper: render with autoescape disabled ---
Procedure.s RendererHelper_RenderNoEscape(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  JinjaError::ClearError()
  Protected NewList tokens.JinjaToken::Token()
  JinjaLexer::Tokenize(templateStr, tokens())
  If JinjaError::HasError()
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *ast.JinjaAST::ASTNode = JinjaParser::Parse(tokens())
  If JinjaError::HasError()
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False
  Protected result.s = JinjaRenderer::Render(*env, *ast, variables())
  JinjaEnv::FreeEnvironment(*env)
  JinjaAST::FreeAST(*ast)
  ProcedureReturn result
EndProcedure

Procedure RunRendererTests()
  PrintN("--- Renderer Tests ---")

  ; =========================================================
  ; Context Tests
  ; =========================================================

  ; --- Context: CreateContext / ScopeDepth ---
  Protected *ctx.JinjaContext::JinjaContext = JinjaContext::CreateContext()
  AssertTrue(Bool(*ctx <> #Null), "Context: CreateContext returns non-null")
  AssertEqual(Str(JinjaContext::ScopeDepth(*ctx)), "1", "Context: initial depth = 1")

  ; --- Context: PushScope / PopScope ---
  JinjaContext::PushScope(*ctx)
  AssertEqual(Str(JinjaContext::ScopeDepth(*ctx)), "2", "Context: depth = 2 after PushScope")
  JinjaContext::PushScope(*ctx)
  AssertEqual(Str(JinjaContext::ScopeDepth(*ctx)), "3", "Context: depth = 3 after second PushScope")
  JinjaContext::PopScope(*ctx)
  AssertEqual(Str(JinjaContext::ScopeDepth(*ctx)), "2", "Context: depth = 2 after PopScope")
  JinjaContext::PopScope(*ctx)
  AssertEqual(Str(JinjaContext::ScopeDepth(*ctx)), "1", "Context: depth = 1 after second PopScope")

  ; Pop past minimum should stay at 1 (cannot remove global scope)
  JinjaContext::PopScope(*ctx)
  AssertEqual(Str(JinjaContext::ScopeDepth(*ctx)), "1", "Context: PopScope at depth 1 stays at 1")

  ; --- Context: SetVariable / GetVariable ---
  Protected setVar.JinjaVariant::JinjaVariant
  Protected getVar.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@setVar, "World")
  JinjaContext::SetVariable(*ctx, "name", @setVar)
  AssertTrue(JinjaContext::HasVariable(*ctx, "name"), "Context: HasVariable finds set variable")
  AssertFalse(JinjaContext::HasVariable(*ctx, "missing"), "Context: HasVariable returns false for missing")

  JinjaContext::GetVariable(*ctx, "name", @getVar)
  AssertEqual(JinjaVariant::ToString(@getVar), "World", "Context: GetVariable retrieves string")
  JinjaVariant::FreeVariant(@getVar)

  ; --- Context: scope shadowing ---
  JinjaContext::PushScope(*ctx)
  Protected innerVar.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@innerVar, "Inner")
  JinjaContext::SetVariable(*ctx, "name", @innerVar)
  JinjaContext::GetVariable(*ctx, "name", @getVar)
  AssertEqual(JinjaVariant::ToString(@getVar), "Inner", "Context: inner scope shadows outer")
  JinjaVariant::FreeVariant(@getVar)
  JinjaContext::PopScope(*ctx)

  ; After pop, outer value is visible again
  JinjaContext::GetVariable(*ctx, "name", @getVar)
  AssertEqual(JinjaVariant::ToString(@getVar), "World", "Context: outer value visible after PopScope")
  JinjaVariant::FreeVariant(@getVar)

  ; --- Context: SetGlobalVariable ---
  Protected globalVar.JinjaVariant::JinjaVariant
  JinjaVariant::IntVariant(@globalVar, 42)
  JinjaContext::SetGlobalVariable(*ctx, "globalKey", @globalVar)
  JinjaContext::GetVariable(*ctx, "globalKey", @getVar)
  AssertEqual(JinjaVariant::ToString(@getVar), "42", "Context: SetGlobalVariable accessible")
  JinjaVariant::FreeVariant(@getVar)

  ; GetVariable on missing key returns Null
  Protected missingVar.JinjaVariant::JinjaVariant
  JinjaContext::GetVariable(*ctx, "notexist", @missingVar)
  AssertEqual(Str(missingVar\VType), Str(Jinja::#VT_Null), "Context: GetVariable missing = Null type")

  JinjaContext::FreeContext(*ctx)

  ; =========================================================
  ; Renderer Pipeline Tests - simple scalars
  ; Scalars (string, int, bool) are safe to assign directly to map
  ; because their raw-copy by value contains no allocated pointers.
  ; =========================================================

  ; --- Simple text rendering ---
  Protected NewMap vars.JinjaVariant::JinjaVariant()
  AssertEqual(RendererHelper_RenderString("Hello World", vars()), "Hello World", "Renderer: plain text passthrough")
  AssertEqual(RendererHelper_RenderString("", vars()), "", "Renderer: empty template")

  ; --- Variable interpolation ---
  Protected tmpV.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@tmpV, "World")
  vars("name") = tmpV
  AssertEqual(RendererHelper_RenderString("Hello {{ name }}", vars()), "Hello World", "Renderer: variable interpolation")

  ; --- Missing variable renders empty ---
  AssertEqual(RendererHelper_RenderString("{{ missing }}", vars()), "", "Renderer: missing variable = empty")

  ; --- Integer variable ---
  JinjaVariant::IntVariant(@tmpV, 99)
  vars("count") = tmpV
  AssertEqual(RendererHelper_RenderString("Count: {{ count }}", vars()), "Count: 99", "Renderer: integer variable")

  ; --- If true branch ---
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars("show") = tmpV
  AssertEqual(RendererHelper_RenderString("{% if show %}yes{% endif %}", vars()), "yes", "Renderer: if true renders body")

  ; --- If false branch ---
  JinjaVariant::BoolVariant(@tmpV, #False)
  vars("show") = tmpV
  AssertEqual(RendererHelper_RenderString("{% if show %}yes{% endif %}", vars()), "", "Renderer: if false skips body")

  ; --- If/else true ---
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars("show") = tmpV
  AssertEqual(RendererHelper_RenderString("{% if show %}yes{% else %}no{% endif %}", vars()), "yes", "Renderer: if/else true branch")

  ; --- If/else false ---
  JinjaVariant::BoolVariant(@tmpV, #False)
  vars("show") = tmpV
  AssertEqual(RendererHelper_RenderString("{% if show %}yes{% else %}no{% endif %}", vars()), "no", "Renderer: if/else false branch")

  ; =========================================================
  ; For loop tests - list variants
  ; We use a separate map per list test to avoid dangling pointer
  ; issues: after Render(), InitFromMap deep-copies into the context,
  ; so the map's raw-copied ListPtr is used only during Render.
  ; We must NOT FreeVariant the local listV after assigning to map.
  ; =========================================================

  ; --- For loop rendering ---
  Protected listV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@listV)
  Protected itemV.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@itemV, "a")
  JinjaVariant::VListAdd(@listV, @itemV)
  JinjaVariant::StrVariant(@itemV, "b")
  JinjaVariant::VListAdd(@listV, @itemV)
  JinjaVariant::StrVariant(@itemV, "c")
  JinjaVariant::VListAdd(@listV, @itemV)

  Protected NewMap forVars.JinjaVariant::JinjaVariant()
  ; Assign by value - shares ListPtr, OK as long as we render before freeing
  forVars("items") = listV
  AssertEqual(RendererHelper_RenderString("{% for i in items %}{{ i }}{% endfor %}", forVars()), "abc", "Renderer: for loop over list")
  AssertEqual(RendererHelper_RenderString("{% for i in items %}{{ i }},{% endfor %}", forVars()), "a,b,c,", "Renderer: for loop with comma")
  ; Free the underlying list only via the local (the map has a raw copy of the pointer)
  JinjaVariant::FreeVariant(@listV)
  ClearMap(forVars())   ; invalidate map entries to prevent dangling pointer use

  ; --- For loop empty list uses else ---
  Protected emptyList.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@emptyList)
  Protected NewMap emptyForVars.JinjaVariant::JinjaVariant()
  emptyForVars("empty") = emptyList
  AssertEqual(RendererHelper_RenderString("{% for i in empty %}{{ i }}{% else %}none{% endfor %}", emptyForVars()), "none", "Renderer: for loop empty uses else")
  JinjaVariant::FreeVariant(@emptyList)
  ClearMap(emptyForVars())

  ; --- Set statement ---
  Protected NewMap setVars.JinjaVariant::JinjaVariant()
  AssertEqual(RendererHelper_RenderString("{% set x = 5 %}{{ x }}", setVars()), "5", "Renderer: set statement integer")
  AssertEqual(RendererHelper_RenderString("{% set msg = " + Chr(34) + "hello" + Chr(34) + " %}{{ msg }}", setVars()), "hello", "Renderer: set statement string")

  ; --- Set then use in condition ---
  AssertEqual(RendererHelper_RenderString("{% set flag = true %}{% if flag %}ok{% endif %}", setVars()), "ok", "Renderer: set boolean used in if")

  ; --- Nested variable access (map attribute) ---
  Protected mapV.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@mapV)
  JinjaVariant::StrVariant(@tmpV, "Alice")
  JinjaVariant::VMapSet(@mapV, "name", @tmpV)

  Protected NewMap nestedVars.JinjaVariant::JinjaVariant()
  nestedVars("user") = mapV
  AssertEqual(RendererHelper_RenderString("{{ user.name }}", nestedVars()), "Alice", "Renderer: nested map attribute access")
  JinjaVariant::FreeVariant(@mapV)
  ClearMap(nestedVars())

  ; --- HTML auto-escaping enabled (default) ---
  JinjaVariant::StrVariant(@tmpV, "<b>bold</b>")
  vars("html_content") = tmpV
  AssertEqual(RendererHelper_RenderString("{{ html_content }}", vars()), "&lt;b&gt;bold&lt;/b&gt;", "Renderer: HTML auto-escape <b>")

  JinjaVariant::StrVariant(@tmpV, "a & b")
  vars("html_content") = tmpV
  AssertEqual(RendererHelper_RenderString("{{ html_content }}", vars()), "a &amp; b", "Renderer: HTML auto-escape &")

  JinjaVariant::StrVariant(@tmpV, Chr(34) + "quoted" + Chr(34))
  vars("html_content") = tmpV
  AssertEqual(RendererHelper_RenderString("{{ html_content }}", vars()), "&quot;quoted&quot;", "Renderer: HTML auto-escape quotes")

  JinjaVariant::StrVariant(@tmpV, "it's here")
  vars("html_content") = tmpV
  AssertEqual(RendererHelper_RenderString("{{ html_content }}", vars()), "it&#39;s here", "Renderer: HTML auto-escape apostrophe")

  ; --- Markup type bypasses auto-escape ---
  Protected markupV.JinjaVariant::JinjaVariant
  JinjaVariant::MarkupVariant(@markupV, "<b>safe</b>")
  Protected NewMap markupVars.JinjaVariant::JinjaVariant()
  markupVars("safe_html") = markupV
  AssertEqual(RendererHelper_RenderString("{{ safe_html }}", markupVars()), "<b>safe</b>", "Renderer: Markup variant bypasses escape")

  ; --- Auto-escape disabled ---
  Protected NewMap rawVars.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "<b>raw</b>")
  rawVars("html") = tmpV
  AssertEqual(RendererHelper_RenderNoEscape("{{ html }}", rawVars()), "<b>raw</b>", "Renderer: no autoescape outputs raw HTML")

  ; --- Loop variable (loop.index, loop.index0) ---
  Protected loopListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@loopListV)
  JinjaVariant::StrVariant(@itemV, "x")
  JinjaVariant::VListAdd(@loopListV, @itemV)
  JinjaVariant::StrVariant(@itemV, "y")
  JinjaVariant::VListAdd(@loopListV, @itemV)

  Protected NewMap loopVars.JinjaVariant::JinjaVariant()
  loopVars("items") = loopListV
  AssertEqual(RendererHelper_RenderString("{% for i in items %}{{ loop.index }}{% endfor %}", loopVars()), "12", "Renderer: loop.index is 1-based")
  AssertEqual(RendererHelper_RenderString("{% for i in items %}{{ loop.index0 }}{% endfor %}", loopVars()), "01", "Renderer: loop.index0 is 0-based")
  JinjaVariant::FreeVariant(@loopListV)
  ClearMap(loopVars())

  ; --- Arithmetic in template ---
  Protected NewMap mathVars.JinjaVariant::JinjaVariant()
  JinjaVariant::IntVariant(@tmpV, 10)
  mathVars("a") = tmpV
  JinjaVariant::IntVariant(@tmpV, 3)
  mathVars("b") = tmpV
  AssertEqual(RendererHelper_RenderString("{{ a + b }}", mathVars()), "13", "Renderer: integer addition")
  AssertEqual(RendererHelper_RenderString("{{ a - b }}", mathVars()), "7", "Renderer: integer subtraction")
  AssertEqual(RendererHelper_RenderString("{{ a * b }}", mathVars()), "30", "Renderer: integer multiplication")

  PrintN("")
EndProcedure
