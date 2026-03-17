; ============================================================================
; PureJinja - TestImport.pbi
; Tests for {% from "template" import macro_name %}
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Helper: render mainSrc with a DictLoader that also has macrosSrc as "macros.html"
; ---------------------------------------------------------------------------
Procedure.s Imp_RenderWithLoader(macrosSrc.s, mainSrc.s)
  JinjaError::ClearError()

  Protected *loader.JinjaLoader::TemplateLoader = JinjaLoader::CreateDictLoader()
  JinjaLoader::DictLoaderAdd(*loader, "macros.html", macrosSrc)
  JinjaLoader::DictLoaderAdd(*loader, "main.html", mainSrc)

  Protected NewList imptokens.JinjaToken::Token()
  JinjaLexer::Tokenize(mainSrc, imptokens())
  If JinjaError::HasError()
    JinjaLoader::FreeLoader(*loader)
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *impast.JinjaAST::ASTNode = JinjaParser::Parse(imptokens())
  If JinjaError::HasError()
    JinjaLoader::FreeLoader(*loader)
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected *impenv.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *impenv\Autoescape = #False
  JinjaEnv::SetLoader(*impenv, *loader)

  Protected NewMap impvars.JinjaVariant::JinjaVariant()
  Protected impresult.s = JinjaRenderer::Render(*impenv, *impast, impvars())

  JinjaAST::FreeAST(*impast)
  JinjaEnv::FreeEnvironment(*impenv)
  ProcedureReturn impresult
EndProcedure

; ---------------------------------------------------------------------------
; Tests
; ---------------------------------------------------------------------------
Procedure RunImportTests()
  PrintN("--- Import Tests ---")

  Protected imp_macros.s
  Protected imp_main.s
  Protected imp_result.s
  Protected imp_q.s = Chr(34)

  ; Test 1: Import a simple macro
  imp_macros = "{% macro greet(name) %}Hello, {{ name }}!{% endmacro %}"
  imp_main = "{% from " + imp_q + "macros.html" + imp_q + " import greet %}{{ greet(" + imp_q + "World" + imp_q + ") }}"
  AssertEqual(Imp_RenderWithLoader(imp_macros, imp_main), "Hello, World!", "import: simple single macro")

  ; Test 2: Import multiple macros
  imp_macros = "{% macro bold(text) %}<b>{{ text }}</b>{% endmacro %}{% macro italic(text) %}<i>{{ text }}</i>{% endmacro %}"
  imp_main = "{% from " + imp_q + "macros.html" + imp_q + " import bold, italic %}{{ bold(" + imp_q + "hi" + imp_q + ") }} {{ italic(" + imp_q + "there" + imp_q + ") }}"
  AssertEqual(Imp_RenderWithLoader(imp_macros, imp_main), "<b>hi</b> <i>there</i>", "import: multiple macros")

  ; Test 3: Import macro with multiple parameters
  imp_macros = "{% macro link(url, text) %}<a href=" + imp_q + "{{ url }}" + imp_q + ">{{ text }}</a>{% endmacro %}"
  imp_main = "{% from " + imp_q + "macros.html" + imp_q + " import link %}{{ link(" + imp_q + "/home" + imp_q + ", " + imp_q + "Home" + imp_q + ") }}"
  AssertEqual(Imp_RenderWithLoader(imp_macros, imp_main), "<a href=" + imp_q + "/home" + imp_q + ">Home</a>", "import: macro with two parameters")

  ; Test 4: Import only one of multiple available macros
  imp_macros = "{% macro alpha() %}A{% endmacro %}{% macro beta() %}B{% endmacro %}"
  imp_main = "{% from " + imp_q + "macros.html" + imp_q + " import alpha %}{{ alpha() }}"
  AssertEqual(Imp_RenderWithLoader(imp_macros, imp_main), "A", "import: selective import (only alpha, not beta)")

  ; Test 5: Macro with no parameters
  imp_macros = "{% macro copyright() %}(c) 2025{% endmacro %}"
  imp_main = "{% from " + imp_q + "macros.html" + imp_q + " import copyright %}{{ copyright() }}"
  AssertEqual(Imp_RenderWithLoader(imp_macros, imp_main), "(c) 2025", "import: no-parameter macro")

  ; Test 6: Macro body containing conditional logic
  imp_macros = "{% macro label(active) %}{% if active %}on{% else %}off{% endif %}{% endmacro %}"
  imp_main = "{% from " + imp_q + "macros.html" + imp_q + " import label %}{{ label(1) }}-{{ label(0) }}"
  AssertEqual(Imp_RenderWithLoader(imp_macros, imp_main), "on-off", "import: macro with conditional body")

  ; Test 7: Multiple calls to same imported macro
  imp_macros = "{% macro item(x) %}-{{ x }}-{% endmacro %}"
  imp_main = "{% from " + imp_q + "macros.html" + imp_q + " import item %}{{ item(" + imp_q + "a" + imp_q + ") }}{{ item(" + imp_q + "b" + imp_q + ") }}{{ item(" + imp_q + "c" + imp_q + ") }}"
  AssertEqual(Imp_RenderWithLoader(imp_macros, imp_main), "-a--b--c-", "import: multiple calls to same macro")

EndProcedure
