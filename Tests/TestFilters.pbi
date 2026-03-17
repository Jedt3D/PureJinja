; ============================================================================
; PureJinja - TestFilters.pbi
; Unit tests for built-in Jinja filters
; Strategy: use the full pipeline (template rendering) for all filter tests.
; This tests filters as they are actually used: via environment filter lookup.
; Direct filter procedure calls are also exercised via the Environment filter map.
; ============================================================================
EnableExplicit

; --- Helper: render template with autoescape OFF (so filter output is raw) ---
Procedure.s FiltersHelper_Render(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
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

; --- Helper: render template with autoescape ON ---
Procedure.s FiltersHelper_RenderEscape(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
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

; --- Helper: call a named filter directly via environment filter map ---
; Creates a temporary environment, looks up the filter, calls it with *value.
Procedure.s FiltersHelper_CallDirect(filterName.s, *value.JinjaVariant::JinjaVariant)
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  Protected filterAddr.i = JinjaEnv::GetFilter(*env, filterName)
  Protected result.JinjaVariant::JinjaVariant
  If filterAddr
    Protected proto.JinjaEnv::ProtoFilter = filterAddr
    proto(*value, #Null, 0, @result)
  EndIf
  Protected s.s = JinjaVariant::ToString(@result)
  JinjaVariant::FreeVariant(@result)
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn s
EndProcedure

; --- Helper: call a named filter with one string argument ---
Procedure.s FiltersHelper_CallWithArg(filterName.s, *value.JinjaVariant::JinjaVariant, arg1.s)
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  Protected filterAddr.i = JinjaEnv::GetFilter(*env, filterName)
  Protected result.JinjaVariant::JinjaVariant
  If filterAddr
    Protected argSlot.JinjaVariant::JinjaVariant
    JinjaVariant::StrVariant(@argSlot, arg1)
    Protected proto.JinjaEnv::ProtoFilter = filterAddr
    proto(*value, @argSlot, 1, @result)
    JinjaVariant::FreeVariant(@argSlot)
  EndIf
  Protected s.s = JinjaVariant::ToString(@result)
  JinjaVariant::FreeVariant(@result)
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn s
EndProcedure

; --- Helper: call a named filter with two string arguments ---
Procedure.s FiltersHelper_CallWith2Args(filterName.s, *value.JinjaVariant::JinjaVariant, arg1.s, arg2.s)
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  Protected filterAddr.i = JinjaEnv::GetFilter(*env, filterName)
  Protected result.JinjaVariant::JinjaVariant
  If filterAddr
    Protected *args.JinjaVariant::JinjaVariant = AllocateMemory(2 * SizeOf(JinjaVariant::JinjaVariant))
    If *args
      Protected *s0.JinjaVariant::JinjaVariant = *args
      Protected *s1.JinjaVariant::JinjaVariant = *args + SizeOf(JinjaVariant::JinjaVariant)
      JinjaVariant::StrVariant(*s0, arg1)
      JinjaVariant::StrVariant(*s1, arg2)
      Protected proto.JinjaEnv::ProtoFilter = filterAddr
      proto(*value, *args, 2, @result)
      JinjaVariant::FreeVariant(*s0)
      JinjaVariant::FreeVariant(*s1)
      FreeMemory(*args)
    EndIf
  EndIf
  Protected s.s = JinjaVariant::ToString(@result)
  JinjaVariant::FreeVariant(@result)
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn s
EndProcedure

Procedure RunFilterTests()
  PrintN("--- Filter Tests ---")

  Protected v.JinjaVariant::JinjaVariant
  Protected tmpV.JinjaVariant::JinjaVariant
  Protected itemV.JinjaVariant::JinjaVariant
  Protected NewMap vars.JinjaVariant::JinjaVariant()

  ; =========================================================
  ; Direct filter unit tests via environment filter map
  ; =========================================================

  ; --- upper filter ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallDirect("upper", @v), "HELLO", "Filter upper: hello -> HELLO")

  JinjaVariant::StrVariant(@v, "Hello World")
  AssertEqual(FiltersHelper_CallDirect("upper", @v), "HELLO WORLD", "Filter upper: mixed case")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("upper", @v), "", "Filter upper: empty string")

  ; --- lower filter ---
  JinjaVariant::StrVariant(@v, "HELLO")
  AssertEqual(FiltersHelper_CallDirect("lower", @v), "hello", "Filter lower: HELLO -> hello")

  JinjaVariant::StrVariant(@v, "Mixed CASE")
  AssertEqual(FiltersHelper_CallDirect("lower", @v), "mixed case", "Filter lower: mixed case")

  ; --- title filter ---
  JinjaVariant::StrVariant(@v, "hello world")
  AssertEqual(FiltersHelper_CallDirect("title", @v), "Hello World", "Filter title: hello world -> Hello World")

  JinjaVariant::StrVariant(@v, "the quick brown fox")
  AssertEqual(FiltersHelper_CallDirect("title", @v), "The Quick Brown Fox", "Filter title: sentence case")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("title", @v), "", "Filter title: empty string")

  ; --- capitalize filter ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallDirect("capitalize", @v), "Hello", "Filter capitalize: hello -> Hello")

  JinjaVariant::StrVariant(@v, "HELLO WORLD")
  AssertEqual(FiltersHelper_CallDirect("capitalize", @v), "Hello world", "Filter capitalize: ALL CAPS -> first letter only")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("capitalize", @v), "", "Filter capitalize: empty string")

  ; --- trim filter ---
  JinjaVariant::StrVariant(@v, "  hello  ")
  AssertEqual(FiltersHelper_CallDirect("trim", @v), "hello", "Filter trim: removes surrounding spaces")

  JinjaVariant::StrVariant(@v, "no spaces")
  AssertEqual(FiltersHelper_CallDirect("trim", @v), "no spaces", "Filter trim: no change when no spaces")

  JinjaVariant::StrVariant(@v, "   ")
  AssertEqual(FiltersHelper_CallDirect("trim", @v), "", "Filter trim: all whitespace -> empty")

  ; --- length filter (string) ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallDirect("length", @v), "5", "Filter length: string hello = 5")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("length", @v), "0", "Filter length: empty string = 0")

  JinjaVariant::StrVariant(@v, "ab")
  AssertEqual(FiltersHelper_CallDirect("length", @v), "2", "Filter length: ab = 2")

  ; --- length filter (list) ---
  Protected listV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@listV)
  JinjaVariant::StrVariant(@itemV, "a")
  JinjaVariant::VListAdd(@listV, @itemV)
  JinjaVariant::StrVariant(@itemV, "b")
  JinjaVariant::VListAdd(@listV, @itemV)
  JinjaVariant::StrVariant(@itemV, "c")
  JinjaVariant::VListAdd(@listV, @itemV)
  AssertEqual(FiltersHelper_CallDirect("length", @listV), "3", "Filter length: list of 3 items = 3")
  JinjaVariant::FreeVariant(@listV)

  ; --- default filter: null -> use default ---
  Protected nullV.JinjaVariant::JinjaVariant
  JinjaVariant::NullVariant(@nullV)
  AssertEqual(FiltersHelper_CallWithArg("default", @nullV, "fallback"), "fallback", "Filter default: null -> fallback")

  ; --- default filter: empty string -> use default ---
  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallWithArg("default", @v, "fallback"), "fallback", "Filter default: empty string -> fallback")

  ; --- default filter: non-empty value -> preserve ---
  JinjaVariant::StrVariant(@v, "actual")
  AssertEqual(FiltersHelper_CallWithArg("default", @v, "fallback"), "actual", "Filter default: non-empty -> original value")

  ; --- replace filter ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallWith2Args("replace", @v, "l", "r"), "herro", "Filter replace: l->r in hello = herro")

  JinjaVariant::StrVariant(@v, "aabbcc")
  AssertEqual(FiltersHelper_CallWith2Args("replace", @v, "b", "X"), "aaXXcc", "Filter replace: replaces all occurrences")

  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallWith2Args("replace", @v, "z", "X"), "hello", "Filter replace: no match -> unchanged")

  ; --- first filter (string) ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallDirect("first", @v), "h", "Filter first: string -> first char")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("first", @v), "", "Filter first: empty string -> empty")

  ; --- first filter (list) ---
  Protected firstListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@firstListV)
  JinjaVariant::StrVariant(@itemV, "alpha")
  JinjaVariant::VListAdd(@firstListV, @itemV)
  JinjaVariant::StrVariant(@itemV, "beta")
  JinjaVariant::VListAdd(@firstListV, @itemV)
  AssertEqual(FiltersHelper_CallDirect("first", @firstListV), "alpha", "Filter first: list -> first element")
  JinjaVariant::FreeVariant(@firstListV)

  ; --- last filter (string) ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallDirect("last", @v), "o", "Filter last: string -> last char")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("last", @v), "", "Filter last: empty string -> empty")

  ; --- last filter (list) ---
  Protected lastListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@lastListV)
  JinjaVariant::StrVariant(@itemV, "one")
  JinjaVariant::VListAdd(@lastListV, @itemV)
  JinjaVariant::StrVariant(@itemV, "two")
  JinjaVariant::VListAdd(@lastListV, @itemV)
  JinjaVariant::StrVariant(@itemV, "three")
  JinjaVariant::VListAdd(@lastListV, @itemV)
  AssertEqual(FiltersHelper_CallDirect("last", @lastListV), "three", "Filter last: list -> last element")
  JinjaVariant::FreeVariant(@lastListV)

  ; --- reverse filter (string) ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(FiltersHelper_CallDirect("reverse", @v), "olleh", "Filter reverse: hello -> olleh")

  JinjaVariant::StrVariant(@v, "abcd")
  AssertEqual(FiltersHelper_CallDirect("reverse", @v), "dcba", "Filter reverse: abcd -> dcba")

  JinjaVariant::StrVariant(@v, "a")
  AssertEqual(FiltersHelper_CallDirect("reverse", @v), "a", "Filter reverse: single char unchanged")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("reverse", @v), "", "Filter reverse: empty string")

  ; --- escape filter ---
  JinjaVariant::StrVariant(@v, "<b>bold</b>")
  AssertEqual(FiltersHelper_CallDirect("escape", @v), "&lt;b&gt;bold&lt;/b&gt;", "Filter escape: escapes HTML tags")

  JinjaVariant::StrVariant(@v, "a & b")
  AssertEqual(FiltersHelper_CallDirect("escape", @v), "a &amp; b", "Filter escape: escapes ampersand")

  ; --- safe filter: marks result as Markup ---
  Protected *envCheck.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  Protected safeAddr.i = JinjaEnv::GetFilter(*envCheck, "safe")
  AssertTrue(Bool(safeAddr <> 0), "Filter safe: registered in environment")
  Protected safeResult.JinjaVariant::JinjaVariant
  If safeAddr
    JinjaVariant::StrVariant(@v, "<b>safe</b>")
    Protected safeProto.JinjaEnv::ProtoFilter = safeAddr
    safeProto(@v, #Null, 0, @safeResult)
    AssertEqual(Str(safeResult\VType), Str(Jinja::#VT_Markup), "Filter safe: marks result as Markup type")
    AssertEqual(JinjaVariant::ToString(@safeResult), "<b>safe</b>", "Filter safe: preserves content")
    JinjaVariant::FreeVariant(@safeResult)
  EndIf
  JinjaEnv::FreeEnvironment(*envCheck)

  ; --- abs filter ---
  Protected negV.JinjaVariant::JinjaVariant
  JinjaVariant::IntVariant(@negV, -42)
  AssertEqual(FiltersHelper_CallDirect("abs", @negV), "42", "Filter abs: -42 -> 42")
  JinjaVariant::IntVariant(@negV, 10)
  AssertEqual(FiltersHelper_CallDirect("abs", @negV), "10", "Filter abs: positive unchanged")

  ; --- int filter ---
  JinjaVariant::StrVariant(@v, "42")
  AssertEqual(FiltersHelper_CallDirect("int", @v), "42", "Filter int: string 42 -> int 42")

  ; --- string filter ---
  Protected intV.JinjaVariant::JinjaVariant
  JinjaVariant::IntVariant(@intV, 123)
  AssertEqual(FiltersHelper_CallDirect("string", @intV), "123", "Filter string: int 123 -> string 123")

  ; --- wordcount filter ---
  JinjaVariant::StrVariant(@v, "hello world foo")
  AssertEqual(FiltersHelper_CallDirect("wordcount", @v), "3", "Filter wordcount: 3 words")

  JinjaVariant::StrVariant(@v, "one")
  AssertEqual(FiltersHelper_CallDirect("wordcount", @v), "1", "Filter wordcount: single word")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(FiltersHelper_CallDirect("wordcount", @v), "0", "Filter wordcount: empty = 0")

  ; --- striptags filter ---
  JinjaVariant::StrVariant(@v, "<b>hello</b> world")
  AssertEqual(FiltersHelper_CallDirect("striptags", @v), "hello world", "Filter striptags: removes HTML tags")

  JinjaVariant::StrVariant(@v, "no tags here")
  AssertEqual(FiltersHelper_CallDirect("striptags", @v), "no tags here", "Filter striptags: no change without tags")

  ; --- truncate filter ---
  JinjaVariant::StrVariant(@v, "hello world")
  AssertEqual(FiltersHelper_CallWithArg("truncate", @v, "5"), "hello...", "Filter truncate: truncates to 5 chars")

  JinjaVariant::StrVariant(@v, "hi")
  AssertEqual(FiltersHelper_CallWithArg("truncate", @v, "10"), "hi", "Filter truncate: short string unchanged")

  ; --- join filter (list) ---
  Protected joinListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@joinListV)
  JinjaVariant::StrVariant(@itemV, "a")
  JinjaVariant::VListAdd(@joinListV, @itemV)
  JinjaVariant::StrVariant(@itemV, "b")
  JinjaVariant::VListAdd(@joinListV, @itemV)
  JinjaVariant::StrVariant(@itemV, "c")
  JinjaVariant::VListAdd(@joinListV, @itemV)
  AssertEqual(FiltersHelper_CallWithArg("join", @joinListV, ","), "a,b,c", "Filter join: list with comma separator")
  AssertEqual(FiltersHelper_CallWithArg("join", @joinListV, " "), "a b c", "Filter join: list with space separator")
  AssertEqual(FiltersHelper_CallWithArg("join", @joinListV, ""), "abc", "Filter join: list with empty separator")
  JinjaVariant::FreeVariant(@joinListV)

  ; --- filter aliases ---
  Protected *envAlias.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  AssertTrue(JinjaEnv::HasFilter(*envAlias, "count"), "Filter alias: count is registered")
  AssertTrue(JinjaEnv::HasFilter(*envAlias, "d"), "Filter alias: d (default) is registered")
  AssertTrue(JinjaEnv::HasFilter(*envAlias, "e"), "Filter alias: e (escape) is registered")
  JinjaEnv::FreeEnvironment(*envAlias)

  ; =========================================================
  ; Pipeline tests: filters in template expressions
  ; =========================================================

  JinjaVariant::StrVariant(@tmpV, "hello")
  vars("word") = tmpV
  AssertEqual(FiltersHelper_Render("{{ word|upper }}", vars()), "HELLO", "Filter pipeline: word|upper")
  AssertEqual(FiltersHelper_Render("{{ word|capitalize }}", vars()), "Hello", "Filter pipeline: word|capitalize")

  JinjaVariant::StrVariant(@tmpV, "HELLO")
  vars("word") = tmpV
  AssertEqual(FiltersHelper_Render("{{ word|lower }}", vars()), "hello", "Filter pipeline: word|lower")

  JinjaVariant::StrVariant(@tmpV, "hello world")
  vars("phrase") = tmpV
  AssertEqual(FiltersHelper_Render("{{ phrase|title }}", vars()), "Hello World", "Filter pipeline: phrase|title")

  JinjaVariant::StrVariant(@tmpV, "  spaces  ")
  vars("padded") = tmpV
  AssertEqual(FiltersHelper_Render("{{ padded|trim }}", vars()), "spaces", "Filter pipeline: padded|trim")

  JinjaVariant::StrVariant(@tmpV, "hello")
  vars("word") = tmpV
  AssertEqual(FiltersHelper_Render("{{ word|length }}", vars()), "5", "Filter pipeline: word|length")

  ; --- filter chaining: upper then reverse ---
  JinjaVariant::StrVariant(@tmpV, "hello")
  vars("word") = tmpV
  AssertEqual(FiltersHelper_Render("{{ word|upper|reverse }}", vars()), "OLLEH", "Filter pipeline: word|upper|reverse")

  ; --- filter chaining: title then upper ---
  JinjaVariant::StrVariant(@tmpV, "hello world")
  vars("phrase") = tmpV
  AssertEqual(FiltersHelper_Render("{{ phrase|title|upper }}", vars()), "HELLO WORLD", "Filter pipeline: phrase|title|upper")

  ; --- default filter in pipeline ---
  Protected NewMap defVars.JinjaVariant::JinjaVariant()
  AssertEqual(FiltersHelper_Render("{{ missing|default(" + Chr(34) + "fallback" + Chr(34) + ") }}", defVars()), "fallback", "Filter pipeline: missing|default(fallback)")

  ; --- replace filter in pipeline ---
  JinjaVariant::StrVariant(@tmpV, "hello")
  vars("word") = tmpV
  AssertEqual(FiltersHelper_Render("{{ word|replace(" + Chr(34) + "l" + Chr(34) + "," + Chr(34) + "r" + Chr(34) + ") }}", vars()), "herro", "Filter pipeline: word|replace(l,r)")

  ; --- escape filter makes Markup, bypasses autoescape ---
  JinjaVariant::StrVariant(@tmpV, "<b>text</b>")
  vars("html") = tmpV
  AssertEqual(FiltersHelper_RenderEscape("{{ html|escape }}", vars()), "&lt;b&gt;text&lt;/b&gt;", "Filter pipeline: escape filter in autoescape mode")

  ; --- safe filter prevents double-escaping ---
  JinjaVariant::StrVariant(@tmpV, "<b>text</b>")
  vars("html") = tmpV
  AssertEqual(FiltersHelper_RenderEscape("{{ html|safe }}", vars()), "<b>text</b>", "Filter pipeline: safe filter bypasses autoescape")

  PrintN("")
EndProcedure
