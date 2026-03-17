; ============================================================================
; PureJinja - TestNewFilters.pbi
; Tests for newly added built-in filters:
;   indent, wordwrap, center, urlencode, tojson, unique, map, items
; ============================================================================
EnableExplicit

; --- Helper: render template with autoescape OFF ---
Procedure.s NewFiltersHelper_Render(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
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

; --- Helper: call filter directly with no args ---
Procedure.s NewFiltersHelper_CallDirect(filterName.s, *value.JinjaVariant::JinjaVariant)
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

; --- Helper: call filter with one integer argument ---
Procedure.s NewFiltersHelper_CallWithIntArg(filterName.s, *value.JinjaVariant::JinjaVariant, arg1.i)
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  Protected filterAddr.i = JinjaEnv::GetFilter(*env, filterName)
  Protected result.JinjaVariant::JinjaVariant
  If filterAddr
    Protected argSlot.JinjaVariant::JinjaVariant
    JinjaVariant::IntVariant(@argSlot, arg1)
    Protected proto.JinjaEnv::ProtoFilter = filterAddr
    proto(*value, @argSlot, 1, @result)
    JinjaVariant::FreeVariant(@argSlot)
  EndIf
  Protected s.s = JinjaVariant::ToString(@result)
  JinjaVariant::FreeVariant(@result)
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn s
EndProcedure

; --- Helper: call filter with one string argument ---
Procedure.s NewFiltersHelper_CallWithStrArg(filterName.s, *value.JinjaVariant::JinjaVariant, arg1.s)
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

; --- Helper: call filter, return actual JinjaVariant (caller must free) ---
Procedure NewFiltersHelper_CallToVariant(filterName.s, *value.JinjaVariant::JinjaVariant, *result.JinjaVariant::JinjaVariant)
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  Protected filterAddr.i = JinjaEnv::GetFilter(*env, filterName)
  If filterAddr
    Protected proto.JinjaEnv::ProtoFilter = filterAddr
    proto(*value, #Null, 0, *result)
  EndIf
  JinjaEnv::FreeEnvironment(*env)
EndProcedure

Procedure RunNewFilterTests()
  PrintN("--- New Filter Tests ---")

  Protected v.JinjaVariant::JinjaVariant
  Protected itemV.JinjaVariant::JinjaVariant
  Protected resultV.JinjaVariant::JinjaVariant
  Protected tmpV.JinjaVariant::JinjaVariant
  Protected NewMap vars.JinjaVariant::JinjaVariant()

  ; ===========================================================
  ; indent filter
  ; ===========================================================

  ; Default: 4 spaces, first line NOT indented
  JinjaVariant::StrVariant(@v, "line1" + Chr(10) + "line2")
  AssertEqual(NewFiltersHelper_CallWithIntArg("indent", @v, 4),
              "line1" + Chr(10) + "    line2",
              "Filter indent: default 4 spaces, first line skipped")

  ; Custom width: 2 spaces
  JinjaVariant::StrVariant(@v, "line1" + Chr(10) + "line2")
  AssertEqual(NewFiltersHelper_CallWithIntArg("indent", @v, 2),
              "line1" + Chr(10) + "  line2",
              "Filter indent: 2 spaces width")

  ; Single line: no newlines, first line unchanged (no indent by default)
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(NewFiltersHelper_CallWithIntArg("indent", @v, 4),
              "hello",
              "Filter indent: single line unchanged")

  ; Empty string
  JinjaVariant::StrVariant(@v, "")
  AssertEqual(NewFiltersHelper_CallWithIntArg("indent", @v, 4),
              "",
              "Filter indent: empty string unchanged")

  ; Three lines, default width=4
  JinjaVariant::StrVariant(@v, "a" + Chr(10) + "b" + Chr(10) + "c")
  AssertEqual(NewFiltersHelper_CallWithIntArg("indent", @v, 4),
              "a" + Chr(10) + "    b" + Chr(10) + "    c",
              "Filter indent: three lines, second and third indented")

  ; Template pipeline test
  JinjaVariant::StrVariant(@tmpV, "foo" + Chr(10) + "bar")
  vars("text") = tmpV
  AssertEqual(NewFiltersHelper_Render("{{ text|indent(2) }}", vars()),
              "foo" + Chr(10) + "  bar",
              "Filter indent: pipeline with width=2")

  ; ===========================================================
  ; wordwrap filter
  ; ===========================================================

  ; Simple wrap at word boundary
  JinjaVariant::StrVariant(@v, "hello world foo bar")
  AssertEqual(NewFiltersHelper_CallWithIntArg("wordwrap", @v, 11),
              "hello world" + Chr(10) + "foo bar",
              "Filter wordwrap: wraps at word boundary width=11")

  ; Width larger than text: no wrap
  JinjaVariant::StrVariant(@v, "short text")
  AssertEqual(NewFiltersHelper_CallWithIntArg("wordwrap", @v, 80),
              "short text",
              "Filter wordwrap: no wrap when text fits")

  ; Single word longer than width: output unchanged (no break mid-word)
  JinjaVariant::StrVariant(@v, "superlongword")
  AssertEqual(NewFiltersHelper_CallWithIntArg("wordwrap", @v, 5),
              "superlongword",
              "Filter wordwrap: long single word passes through")

  ; Empty string
  JinjaVariant::StrVariant(@v, "")
  AssertEqual(NewFiltersHelper_CallWithIntArg("wordwrap", @v, 10),
              "",
              "Filter wordwrap: empty string unchanged")

  ; Template pipeline test
  JinjaVariant::StrVariant(@tmpV, "one two three four")
  vars("text") = tmpV
  AssertEqual(NewFiltersHelper_Render("{{ text|wordwrap(9) }}", vars()),
              "one two" + Chr(10) + "three" + Chr(10) + "four",
              "Filter wordwrap: pipeline wraps correctly")

  ; ===========================================================
  ; center filter
  ; ===========================================================

  ; Center "hello" (5 chars) in width=11 -> 3 spaces each side
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(NewFiltersHelper_CallWithIntArg("center", @v, 11),
              "   hello   ",
              "Filter center: 5 chars in width 11 -> 3 spaces each side")

  ; Exact fit: no padding added
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(NewFiltersHelper_CallWithIntArg("center", @v, 5),
              "hello",
              "Filter center: text exactly fills width -> no padding")

  ; Text longer than width: returned unchanged
  JinjaVariant::StrVariant(@v, "hello world")
  AssertEqual(NewFiltersHelper_CallWithIntArg("center", @v, 5),
              "hello world",
              "Filter center: text longer than width -> returned as-is")

  ; Odd padding: left gets floor, right gets ceil
  JinjaVariant::StrVariant(@v, "hi")
  AssertEqual(NewFiltersHelper_CallWithIntArg("center", @v, 5),
              " hi  ",
              "Filter center: odd padding - left gets 1, right gets 2")

  ; Empty string
  JinjaVariant::StrVariant(@v, "")
  AssertEqual(NewFiltersHelper_CallWithIntArg("center", @v, 4),
              "    ",
              "Filter center: empty string gets all spaces")

  ; Template pipeline test
  JinjaVariant::StrVariant(@tmpV, "ok")
  vars("word") = tmpV
  AssertEqual(NewFiltersHelper_Render("{{ word|center(6) }}", vars()),
              "  ok  ",
              "Filter center: pipeline centering")

  ; ===========================================================
  ; urlencode filter
  ; ===========================================================

  ; Space becomes %20
  JinjaVariant::StrVariant(@v, "hello world")
  AssertEqual(NewFiltersHelper_CallDirect("urlencode", @v),
              "hello%20world",
              "Filter urlencode: space -> %20")

  ; Ampersand and equals
  JinjaVariant::StrVariant(@v, "a&b=c")
  AssertEqual(NewFiltersHelper_CallDirect("urlencode", @v),
              "a%26b%3Dc",
              "Filter urlencode: & and = encoded")

  ; Safe chars pass through
  JinjaVariant::StrVariant(@v, "hello-world_test.ok~")
  AssertEqual(NewFiltersHelper_CallDirect("urlencode", @v),
              "hello-world_test.ok~",
              "Filter urlencode: safe chars pass through")

  ; Empty string
  JinjaVariant::StrVariant(@v, "")
  AssertEqual(NewFiltersHelper_CallDirect("urlencode", @v),
              "",
              "Filter urlencode: empty string unchanged")

  ; Slash is encoded
  JinjaVariant::StrVariant(@v, "path/to/file")
  AssertEqual(NewFiltersHelper_CallDirect("urlencode", @v),
              "path%2Fto%2Ffile",
              "Filter urlencode: slashes encoded")

  ; Template pipeline test
  JinjaVariant::StrVariant(@tmpV, "q=hello world")
  vars("query") = tmpV
  AssertEqual(NewFiltersHelper_Render("{{ query|urlencode }}", vars()),
              "q%3Dhello%20world",
              "Filter urlencode: pipeline encodes = and space")

  ; ===========================================================
  ; tojson filter
  ; ===========================================================

  ; String value
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(NewFiltersHelper_CallDirect("tojson", @v),
              Chr(34) + "hello" + Chr(34),
              "Filter tojson: string gets quoted")

  ; Integer value
  JinjaVariant::IntVariant(@v, 42)
  AssertEqual(NewFiltersHelper_CallDirect("tojson", @v),
              "42",
              "Filter tojson: integer -> bare number")

  ; Boolean true
  JinjaVariant::BoolVariant(@v, #True)
  AssertEqual(NewFiltersHelper_CallDirect("tojson", @v),
              "true",
              "Filter tojson: true -> true")

  ; Boolean false
  JinjaVariant::BoolVariant(@v, #False)
  AssertEqual(NewFiltersHelper_CallDirect("tojson", @v),
              "false",
              "Filter tojson: false -> false")

  ; Null value
  JinjaVariant::NullVariant(@v)
  AssertEqual(NewFiltersHelper_CallDirect("tojson", @v),
              "null",
              "Filter tojson: null -> null")

  ; String with double-quote needs escaping
  JinjaVariant::StrVariant(@v, "say " + Chr(34) + "hi" + Chr(34))
  AssertEqual(NewFiltersHelper_CallDirect("tojson", @v),
              Chr(34) + "say " + Chr(92) + Chr(34) + "hi" + Chr(92) + Chr(34) + Chr(34),
              "Filter tojson: embedded quotes escaped")

  ; List of integers
  Protected jsonListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@jsonListV)
  JinjaVariant::IntVariant(@itemV, 1)
  JinjaVariant::VListAdd(@jsonListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 2)
  JinjaVariant::VListAdd(@jsonListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 3)
  JinjaVariant::VListAdd(@jsonListV, @itemV)
  AssertEqual(NewFiltersHelper_CallDirect("tojson", @jsonListV),
              "[1, 2, 3]",
              "Filter tojson: list of ints -> JSON array")
  JinjaVariant::FreeVariant(@jsonListV)

  ; Template pipeline test
  JinjaVariant::StrVariant(@tmpV, "test")
  vars("val") = tmpV
  AssertEqual(NewFiltersHelper_Render("{{ val|tojson }}", vars()),
              Chr(34) + "test" + Chr(34),
              "Filter tojson: pipeline string -> quoted JSON")

  ; ===========================================================
  ; unique filter
  ; ===========================================================

  ; Integers with duplicates
  Protected uniqListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@uniqListV)
  JinjaVariant::IntVariant(@itemV, 1) : JinjaVariant::VListAdd(@uniqListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 1) : JinjaVariant::VListAdd(@uniqListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 2) : JinjaVariant::VListAdd(@uniqListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 3) : JinjaVariant::VListAdd(@uniqListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 3) : JinjaVariant::VListAdd(@uniqListV, @itemV)
  NewFiltersHelper_CallToVariant("unique", @uniqListV, @resultV)
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "3",
              "Filter unique: [1,1,2,3,3] -> 3 items")
  ; Verify values
  Protected checkItem.JinjaVariant::JinjaVariant
  JinjaVariant::VListGet(@resultV, 0, @checkItem)
  AssertEqual(Str(checkItem\IntVal), "1", "Filter unique: first item = 1")
  JinjaVariant::FreeVariant(@checkItem)
  JinjaVariant::VListGet(@resultV, 1, @checkItem)
  AssertEqual(Str(checkItem\IntVal), "2", "Filter unique: second item = 2")
  JinjaVariant::FreeVariant(@checkItem)
  JinjaVariant::VListGet(@resultV, 2, @checkItem)
  AssertEqual(Str(checkItem\IntVal), "3", "Filter unique: third item = 3")
  JinjaVariant::FreeVariant(@checkItem)
  JinjaVariant::FreeVariant(@resultV)
  JinjaVariant::FreeVariant(@uniqListV)

  ; All unique: no removal
  Protected allUniqV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@allUniqV)
  JinjaVariant::IntVariant(@itemV, 10) : JinjaVariant::VListAdd(@allUniqV, @itemV)
  JinjaVariant::IntVariant(@itemV, 20) : JinjaVariant::VListAdd(@allUniqV, @itemV)
  JinjaVariant::IntVariant(@itemV, 30) : JinjaVariant::VListAdd(@allUniqV, @itemV)
  NewFiltersHelper_CallToVariant("unique", @allUniqV, @resultV)
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "3",
              "Filter unique: all unique -> count unchanged")
  JinjaVariant::FreeVariant(@resultV)
  JinjaVariant::FreeVariant(@allUniqV)

  ; Empty list
  Protected emptyListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@emptyListV)
  NewFiltersHelper_CallToVariant("unique", @emptyListV, @resultV)
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "0",
              "Filter unique: empty list -> empty result")
  JinjaVariant::FreeVariant(@resultV)
  JinjaVariant::FreeVariant(@emptyListV)

  ; String deduplication
  Protected strUniqV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@strUniqV)
  JinjaVariant::StrVariant(@itemV, "a") : JinjaVariant::VListAdd(@strUniqV, @itemV)
  JinjaVariant::StrVariant(@itemV, "b") : JinjaVariant::VListAdd(@strUniqV, @itemV)
  JinjaVariant::StrVariant(@itemV, "a") : JinjaVariant::VListAdd(@strUniqV, @itemV)
  JinjaVariant::StrVariant(@itemV, "c") : JinjaVariant::VListAdd(@strUniqV, @itemV)
  NewFiltersHelper_CallToVariant("unique", @strUniqV, @resultV)
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "3",
              "Filter unique: string list [a,b,a,c] -> 3 items")
  JinjaVariant::FreeVariant(@resultV)
  JinjaVariant::FreeVariant(@strUniqV)

  ; Template pipeline: unique via join to verify output
  Protected NewMap uvars.JinjaVariant::JinjaVariant()
  Protected uListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@uListV)
  JinjaVariant::IntVariant(@itemV, 1) : JinjaVariant::VListAdd(@uListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 2) : JinjaVariant::VListAdd(@uListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 1) : JinjaVariant::VListAdd(@uListV, @itemV)
  JinjaVariant::IntVariant(@itemV, 3) : JinjaVariant::VListAdd(@uListV, @itemV)
  uvars("nums") = uListV
  AssertEqual(NewFiltersHelper_Render("{{ nums|unique|join(" + Chr(34) + "," + Chr(34) + ") }}", uvars()),
              "1,2,3",
              "Filter unique: pipeline unique|join")
  JinjaVariant::FreeVariant(@uListV)

  ; ===========================================================
  ; map filter
  ; ===========================================================

  ; Build a list of map items with a "name" attribute
  Protected mapListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@mapListV)

  Protected user1.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@user1)
  JinjaVariant::StrVariant(@tmpV, "Alice")
  JinjaVariant::VMapSet(@user1, "name", @tmpV)
  JinjaVariant::IntVariant(@tmpV, 30)
  JinjaVariant::VMapSet(@user1, "age", @tmpV)
  JinjaVariant::VListAdd(@mapListV, @user1)
  JinjaVariant::FreeVariant(@user1)

  Protected user2.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@user2)
  JinjaVariant::StrVariant(@tmpV, "Bob")
  JinjaVariant::VMapSet(@user2, "name", @tmpV)
  JinjaVariant::IntVariant(@tmpV, 25)
  JinjaVariant::VMapSet(@user2, "age", @tmpV)
  JinjaVariant::VListAdd(@mapListV, @user2)
  JinjaVariant::FreeVariant(@user2)

  ; map("name") should extract names
  Protected mapResultV.JinjaVariant::JinjaVariant
  NewFiltersHelper_CallToVariant("map", @mapListV, @mapResultV)  ; no attr -> items as-is
  ; Without arg, items pass through unchanged (they are maps)
  AssertEqual(Str(JinjaVariant::VListSize(@mapResultV)), "2",
              "Filter map: no-arg map preserves list size")
  JinjaVariant::FreeVariant(@mapResultV)

  ; Call map with "name" attribute via template pipeline
  Protected NewMap mtvars.JinjaVariant::JinjaVariant()
  mtvars("users") = mapListV
  AssertEqual(NewFiltersHelper_Render("{{ users|map(" + Chr(34) + "name" + Chr(34) + ")|join(" + Chr(34) + "," + Chr(34) + ") }}", mtvars()),
              "Alice,Bob",
              "Filter map: extract name attribute and join")

  AssertEqual(NewFiltersHelper_Render("{{ users|map(" + Chr(34) + "age" + Chr(34) + ")|join(" + Chr(34) + "," + Chr(34) + ") }}", mtvars()),
              "30,25",
              "Filter map: extract age attribute and join")

  JinjaVariant::FreeVariant(@mapListV)

  ; map on empty list
  Protected emptyMapListV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@emptyMapListV)
  NewFiltersHelper_CallToVariant("map", @emptyMapListV, @resultV)
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "0",
              "Filter map: empty list -> empty result")
  JinjaVariant::FreeVariant(@resultV)
  JinjaVariant::FreeVariant(@emptyMapListV)

  ; ===========================================================
  ; items filter
  ; ===========================================================

  ; Build a map
  Protected dictV.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@dictV)
  JinjaVariant::StrVariant(@tmpV, "world")
  JinjaVariant::VMapSet(@dictV, "hello", @tmpV)
  JinjaVariant::IntVariant(@tmpV, 42)
  JinjaVariant::VMapSet(@dictV, "answer", @tmpV)

  ; items should return a list of 2-element lists
  NewFiltersHelper_CallToVariant("items", @dictV, @resultV)
  AssertEqual(Str(resultV\VType), Str(Jinja::#VT_List),
              "Filter items: result is a list")
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "2",
              "Filter items: 2-key map produces 2 pairs")

  ; Each element should be a list of length 2
  Protected pair0.JinjaVariant::JinjaVariant
  JinjaVariant::VListGet(@resultV, 0, @pair0)
  AssertEqual(Str(pair0\VType), Str(Jinja::#VT_List),
              "Filter items: first pair is a list")
  AssertEqual(Str(JinjaVariant::VListSize(@pair0)), "2",
              "Filter items: first pair has 2 elements")
  JinjaVariant::FreeVariant(@pair0)

  JinjaVariant::FreeVariant(@resultV)

  ; Template pipeline: iterate over items
  Protected NewMap itvars.JinjaVariant::JinjaVariant()
  Protected singleDict.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@singleDict)
  JinjaVariant::StrVariant(@tmpV, "bar")
  JinjaVariant::VMapSet(@singleDict, "foo", @tmpV)
  itvars("d") = singleDict

  AssertEqual(NewFiltersHelper_Render("{% for pair in d|items %}{{ pair[0] }}={{ pair[1] }}{% endfor %}", itvars()),
              "foo=bar",
              "Filter items: for loop over items of single-key dict")

  JinjaVariant::FreeVariant(@singleDict)
  JinjaVariant::FreeVariant(@dictV)

  ; items on non-map returns empty list
  JinjaVariant::StrVariant(@v, "not a map")
  NewFiltersHelper_CallToVariant("items", @v, @resultV)
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "0",
              "Filter items: non-map input -> empty list")
  JinjaVariant::FreeVariant(@resultV)

  ; items on empty map
  Protected emptyMapV.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@emptyMapV)
  NewFiltersHelper_CallToVariant("items", @emptyMapV, @resultV)
  AssertEqual(Str(JinjaVariant::VListSize(@resultV)), "0",
              "Filter items: empty map -> empty list")
  JinjaVariant::FreeVariant(@resultV)
  JinjaVariant::FreeVariant(@emptyMapV)

  ; ===========================================================
  ; Registration checks
  ; ===========================================================

  Protected *regEnv.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "indent"),    "Filter registration: indent registered")
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "wordwrap"),  "Filter registration: wordwrap registered")
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "center"),    "Filter registration: center registered")
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "urlencode"), "Filter registration: urlencode registered")
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "tojson"),    "Filter registration: tojson registered")
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "unique"),    "Filter registration: unique registered")
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "map"),       "Filter registration: map registered")
  AssertTrue(JinjaEnv::HasFilter(*regEnv, "items"),     "Filter registration: items registered")
  JinjaEnv::FreeEnvironment(*regEnv)

  PrintN("")
EndProcedure
