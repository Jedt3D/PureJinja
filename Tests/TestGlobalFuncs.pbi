; ============================================================================
; PureJinja - TestGlobalFuncs.pbi
; Tests for dict(), joiner(), and cycler() global functions
; ============================================================================
EnableExplicit

; --- Helper: render a template string with no variables ---
Procedure.s GF_Render(templateStr.s)
  JinjaError::ClearError()
  Protected NewList gftokens.JinjaToken::Token()
  JinjaLexer::Tokenize(templateStr, gftokens())
  If JinjaError::HasError()
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *gfast.JinjaAST::ASTNode = JinjaParser::Parse(gftokens())
  If JinjaError::HasError()
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected *gfenv.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *gfenv\Autoescape = #False
  Protected NewMap gfvars.JinjaVariant::JinjaVariant()
  Protected gfresult.s = JinjaRenderer::Render(*gfenv, *gfast, gfvars())
  JinjaEnv::FreeEnvironment(*gfenv)
  JinjaAST::FreeAST(*gfast)
  ProcedureReturn gfresult
EndProcedure

; --- Helper: render a template string with a list variable named "items" ---
Procedure.s GF_RenderWithItems(templateStr.s, items.s)
  ; items is a comma-separated list of string values
  JinjaError::ClearError()
  Protected NewList gftokens2.JinjaToken::Token()
  JinjaLexer::Tokenize(templateStr, gftokens2())
  If JinjaError::HasError()
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *gfast2.JinjaAST::ASTNode = JinjaParser::Parse(gftokens2())
  If JinjaError::HasError()
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected *gfenv2.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *gfenv2\Autoescape = #False

  Protected NewMap gfvars2.JinjaVariant::JinjaVariant()
  Protected itemsListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsListV)
  Protected itemCount.i = CountString(items, ",") + 1
  Protected i.i
  For i = 1 To itemCount
    Protected itemStr.s = StringField(items, i, ",")
    Protected itemV.JinjaVariant::JinjaVariant
    JinjaVariant::StrVariant(@itemV, itemStr)
    JinjaVariant::VListAdd(@itemsListV, @itemV)
    JinjaVariant::FreeVariant(@itemV)
  Next
  gfvars2("items") = itemsListV

  Protected gfresult2.s = JinjaRenderer::Render(*gfenv2, *gfast2, gfvars2())
  JinjaVariant::FreeVariant(@gfvars2("items"))
  JinjaEnv::FreeEnvironment(*gfenv2)
  JinjaAST::FreeAST(*gfast2)
  ProcedureReturn gfresult2
EndProcedure

Procedure RunGlobalFuncTests()
  PrintN("--- Global Function Tests ---")

  ; ===== dict() Tests =====

  ; Test: dict() creates empty dict, length = 0
  AssertEqual(GF_Render("{% set d = dict() %}{{ d|length }}"),
              "0",
              "dict(): empty dict has length 0")

  ; Test: dict() can have keys set via namespace-style assignment
  ; (Just verify dict() creates a map usable for attribute access later)
  AssertEqual(GF_Render("{% set d = dict() %}{% if d is defined %}yes{% endif %}"),
              "yes",
              "dict(): result is defined")

  ; Test: dict() result is falsy (empty map)
  AssertEqual(GF_Render("{% set d = dict() %}{% if d %}nonempty{% else %}empty{% endif %}"),
              "empty",
              "dict(): empty dict is falsy")

  ; ===== joiner() Tests =====

  ; Test: joiner with default separator in for loop
  ; Template: {% set j = joiner(", ") %}{% for x in items %}{{ j() }}{{ x }}{% endfor %}
  ; items = a,b,c => "a, b, c"
  AssertEqual(GF_RenderWithItems("{% set j = joiner(" + Chr(34) + ", " + Chr(34) + ") %}{% for x in items %}{{ j() }}{{ x }}{% endfor %}",
                                  "a,b,c"),
              "a, b, c",
              "joiner(): comma-separated list a,b,c")

  ; Test: joiner with pipe separator
  ; Template: {% set j = joiner(" | ") %}{{ j() }}a{{ j() }}b{{ j() }}c
  ; => "a | b | c"
  AssertEqual(GF_Render("{% set j = joiner(" + Chr(34) + " | " + Chr(34) + ") %}{{ j() }}a{{ j() }}b{{ j() }}c"),
              "a | b | c",
              "joiner(): pipe-separated inline calls")

  ; Test: joiner single item produces no separator
  AssertEqual(GF_RenderWithItems("{% set j = joiner(" + Chr(34) + ", " + Chr(34) + ") %}{% for x in items %}{{ j() }}{{ x }}{% endfor %}",
                                  "only"),
              "only",
              "joiner(): single item, no separator")

  ; Test: joiner two items
  AssertEqual(GF_RenderWithItems("{% set j = joiner(" + Chr(34) + "-" + Chr(34) + ") %}{% for x in items %}{{ j() }}{{ x }}{% endfor %}",
                                  "first,second"),
              "first-second",
              "joiner(): two items joined by dash")

  ; Test: joiner with no argument uses default ", "
  AssertEqual(GF_RenderWithItems("{% set j = joiner() %}{% for x in items %}{{ j() }}{{ x }}{% endfor %}",
                                  "x,y,z"),
              "x, y, z",
              "joiner(): no-arg uses default separator ', '")

  ; Test: two independent joiners don't interfere
  AssertEqual(GF_Render("{% set j1 = joiner(" + Chr(34) + "," + Chr(34) + ") %}{% set j2 = joiner(" + Chr(34) + ";" + Chr(34) + ") %}{{ j1() }}a{{ j1() }}b{{ j2() }}x{{ j2() }}y"),
              "a,bx;y",
              "joiner(): two independent joiners do not interfere")

  ; ===== cycler() Tests =====

  ; Test: cycler cycles through items
  AssertEqual(GF_Render("{% set c = cycler(" + Chr(34) + "odd" + Chr(34) + ", " + Chr(34) + "even" + Chr(34) + ") %}{{ c() }}{{ c() }}{{ c() }}"),
              "oddevenodd",
              "cycler(): cycles odd/even/odd")

  ; Test: cycler with three items
  AssertEqual(GF_Render("{% set c = cycler(" + Chr(34) + "a" + Chr(34) + ", " + Chr(34) + "b" + Chr(34) + ", " + Chr(34) + "c" + Chr(34) + ") %}{{ c() }}{{ c() }}{{ c() }}{{ c() }}"),
              "abca",
              "cycler(): cycles a/b/c/a")

  ; Test: cycler in a for loop
  AssertEqual(GF_RenderWithItems("{% set c = cycler(" + Chr(34) + "odd" + Chr(34) + ", " + Chr(34) + "even" + Chr(34) + ") %}{% for x in items %}{{ c() }}-{{ x }} {% endfor %}",
                                  "p,q,r"),
              "odd-p even-q odd-r ",
              "cycler(): cycler in for loop")

  ; Test: single-item cycler always returns same value
  AssertEqual(GF_Render("{% set c = cycler(" + Chr(34) + "x" + Chr(34) + ") %}{{ c() }}{{ c() }}{{ c() }}"),
              "xxx",
              "cycler(): single-item always returns same value")

  PrintN("")
EndProcedure
