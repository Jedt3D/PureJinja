; ============================================================================
; PureJinja - TestDict.pbi
; Tests for dict literal syntax {"key": value}
; ============================================================================
EnableExplicit

; --- Helper: render a template string with no variables ---
Procedure.s DictHelper_Render(templateStr.s)
  JinjaError::ClearError()
  Protected NewList dtokens.JinjaToken::Token()
  JinjaLexer::Tokenize(templateStr, dtokens())
  If JinjaError::HasError()
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *dast.JinjaAST::ASTNode = JinjaParser::Parse(dtokens())
  If JinjaError::HasError()
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected *denv.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *denv\Autoescape = #False
  Protected NewMap dvars.JinjaVariant::JinjaVariant()
  Protected dresult.s = JinjaRenderer::Render(*denv, *dast, dvars())
  JinjaEnv::FreeEnvironment(*denv)
  JinjaAST::FreeAST(*dast)
  ProcedureReturn dresult
EndProcedure

Procedure RunDictTests()
  PrintN("--- Dict Literal Tests ---")

  ; Test: Simple dict + attribute access
  ; Template: {% set d = {"name": "Alice"} %}{{ d.name }}
  AssertEqual(DictHelper_Render("{% set d = {" + Chr(34) + "name" + Chr(34) + ": " + Chr(34) + "Alice" + Chr(34) + "} %}{{ d.name }}"),
              "Alice",
              "Dict: simple key access d.name = Alice")

  ; Test: Multiple keys
  ; Template: {% set d = {"a": 1, "b": 2} %}{{ d.a }}-{{ d.b }}
  AssertEqual(DictHelper_Render("{% set d = {" + Chr(34) + "a" + Chr(34) + ": 1, " + Chr(34) + "b" + Chr(34) + ": 2} %}{{ d.a }}-{{ d.b }}"),
              "1-2",
              "Dict: multiple keys d.a and d.b")

  ; Test: Dict with variable value
  ; Template: {% set x = "hello" %}{% set d = {"msg": x} %}{{ d.msg }}
  AssertEqual(DictHelper_Render("{% set x = " + Chr(34) + "hello" + Chr(34) + " %}{% set d = {" + Chr(34) + "msg" + Chr(34) + ": x} %}{{ d.msg }}"),
              "hello",
              "Dict: variable value d.msg = hello")

  ; Test: Nested dict
  ; Template: {% set d = {"user": {"name": "Bob"}} %}{{ d.user.name }}
  AssertEqual(DictHelper_Render("{% set d = {" + Chr(34) + "user" + Chr(34) + ": {" + Chr(34) + "name" + Chr(34) + ": " + Chr(34) + "Bob" + Chr(34) + "}} %}{{ d.user.name }}"),
              "Bob",
              "Dict: nested dict d.user.name = Bob")

  ; Test: Dict with filter
  ; Template: {% set d = {"name": "alice"} %}{{ d.name|upper }}
  AssertEqual(DictHelper_Render("{% set d = {" + Chr(34) + "name" + Chr(34) + ": " + Chr(34) + "alice" + Chr(34) + "} %}{{ d.name|upper }}"),
              "ALICE",
              "Dict: value with filter d.name|upper = ALICE")

  ; Test: Dict in if condition
  ; Template: {% set d = {"active": true} %}{% if d.active %}yes{% endif %}
  AssertEqual(DictHelper_Render("{% set d = {" + Chr(34) + "active" + Chr(34) + ": true} %}{% if d.active %}yes{% endif %}"),
              "yes",
              "Dict: truthy value used in if condition")

  ; Test: Trailing comma
  ; Template: {% set d = {"a": 1,} %}{{ d.a }}
  AssertEqual(DictHelper_Render("{% set d = {" + Chr(34) + "a" + Chr(34) + ": 1,} %}{{ d.a }}"),
              "1",
              "Dict: trailing comma allowed")

  ; Test: Empty dict renders without error
  ; Template: {{ {} }}
  DictHelper_Render("{{ {} }}")
  AssertTrue(Bool(JinjaError::HasError() = #False),
             "Dict: empty dict does not cause an error")

  PrintN("")
EndProcedure
