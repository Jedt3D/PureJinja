; ============================================================================
; PureJinja - TestIntegration.pbi
; End-to-end integration tests using the full template engine pipeline
; Tests use: CreateEnvironment -> JinjaRenderer::Render (full pipeline)
; Note: JinjaEnv::RenderString is a stub; integration uses Renderer directly
; ============================================================================
EnableExplicit

; --- Integration helper: render template string with autoescape ON ---
Procedure.s Integration_Render(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
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

; --- Integration helper: render with autoescape OFF ---
Procedure.s Integration_RenderRaw(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
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

; --- Integration helper: render using DictLoader ---
Procedure.s Integration_RenderTemplate(templateName.s, templateSrc.s, Map variables.JinjaVariant::JinjaVariant())
  JinjaError::ClearError()

  Protected *loader.JinjaLoader::TemplateLoader = JinjaLoader::CreateDictLoader()
  JinjaLoader::DictLoaderAdd(*loader, templateName, templateSrc)

  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False
  JinjaEnv::SetLoader(*env, *loader)

  Protected source.s = JinjaLoader::LoadTemplate(*loader, templateName)
  If JinjaError::HasError()
    JinjaEnv::FreeEnvironment(*env)
    ProcedureReturn "[LoaderError] " + JinjaError::FormatError()
  EndIf

  Protected NewList tokens.JinjaToken::Token()
  JinjaLexer::Tokenize(source, tokens())
  If JinjaError::HasError()
    JinjaEnv::FreeEnvironment(*env)
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *ast.JinjaAST::ASTNode = JinjaParser::Parse(tokens())
  If JinjaError::HasError()
    JinjaEnv::FreeEnvironment(*env)
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected result.s = JinjaRenderer::Render(*env, *ast, variables())
  JinjaEnv::FreeEnvironment(*env)  ; loader freed inside
  JinjaAST::FreeAST(*ast)
  ProcedureReturn result
EndProcedure

Procedure RunIntegrationTests()
  PrintN("--- Integration Tests ---")

  Protected tmpV.JinjaVariant::JinjaVariant
  Protected NewMap vars.JinjaVariant::JinjaVariant()

  ; =========================================================
  ; Test 1: Plain text passthrough
  ; =========================================================
  AssertEqual(Integration_Render("Hello World", vars()), "Hello World", "Integration: plain text")
  AssertEqual(Integration_Render("", vars()), "", "Integration: empty template")
  AssertEqual(Integration_Render("line1" + Chr(10) + "line2", vars()), "line1" + Chr(10) + "line2", "Integration: multiline plain text")

  ; =========================================================
  ; Test 2: Variable substitution
  ; =========================================================
  JinjaVariant::StrVariant(@tmpV, "World")
  vars("name") = tmpV
  AssertEqual(Integration_Render("Hello, {{ name }}!", vars()), "Hello, World!", "Integration: simple variable")

  JinjaVariant::IntVariant(@tmpV, 2024)
  vars("year") = tmpV
  AssertEqual(Integration_Render("Year: {{ year }}", vars()), "Year: 2024", "Integration: integer variable")

  ; Multiple variables in one template
  JinjaVariant::StrVariant(@tmpV, "Jane")
  vars("first") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Doe")
  vars("last") = tmpV
  AssertEqual(Integration_Render("{{ first }} {{ last }}", vars()), "Jane Doe", "Integration: two variables")

  ; =========================================================
  ; Test 3: Conditionals
  ; =========================================================
  Protected NewMap condVars.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #True)
  condVars("admin") = tmpV
  AssertEqual(Integration_RenderRaw("{% if admin %}Admin Panel{% endif %}", condVars()), "Admin Panel", "Integration: if true")

  JinjaVariant::BoolVariant(@tmpV, #False)
  condVars("admin") = tmpV
  AssertEqual(Integration_RenderRaw("{% if admin %}Admin Panel{% endif %}", condVars()), "", "Integration: if false")

  ; if/elif/else
  JinjaVariant::IntVariant(@tmpV, 85)
  condVars("score") = tmpV
  Protected ifElifTpl.s = "{% if score >= 90 %}A{% elif score >= 80 %}B{% elif score >= 70 %}C{% else %}F{% endif %}"
  AssertEqual(Integration_RenderRaw(ifElifTpl, condVars()), "B", "Integration: elif chain score=85 -> B")

  JinjaVariant::IntVariant(@tmpV, 95)
  condVars("score") = tmpV
  AssertEqual(Integration_RenderRaw(ifElifTpl, condVars()), "A", "Integration: elif chain score=95 -> A")

  JinjaVariant::IntVariant(@tmpV, 65)
  condVars("score") = tmpV
  AssertEqual(Integration_RenderRaw(ifElifTpl, condVars()), "F", "Integration: elif chain score=65 -> F")

  ; =========================================================
  ; Test 4: For loops
  ; =========================================================
  Protected NewMap forVars.JinjaVariant::JinjaVariant()
  Protected loopList.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@loopList)
  Protected itemV.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@itemV, "apple")
  JinjaVariant::VListAdd(@loopList, @itemV)
  JinjaVariant::StrVariant(@itemV, "banana")
  JinjaVariant::VListAdd(@loopList, @itemV)
  JinjaVariant::StrVariant(@itemV, "cherry")
  JinjaVariant::VListAdd(@loopList, @itemV)
  forVars("fruits") = loopList
  ; Do NOT FreeVariant(@loopList) here - forVars shares the ListPtr via raw copy

  AssertEqual(Integration_RenderRaw("{% for f in fruits %}{{ f }} {% endfor %}", forVars()), "apple banana cherry ", "Integration: for loop over strings")

  ; For loop with loop.index
  AssertEqual(Integration_RenderRaw("{% for f in fruits %}{{ loop.index }}:{{ f }} {% endfor %}", forVars()), "1:apple 2:banana 3:cherry ", "Integration: for loop with loop.index")

  ; For loop with loop.first and loop.last
  AssertEqual(Integration_RenderRaw("{% for f in fruits %}{% if loop.first %}[{% endif %}{{ f }}{% if loop.last %}]{% endif %}{% endfor %}", forVars()), "[apple" + "banana" + "cherry]", "Integration: for loop.first/last")

  ; For loop: range() function
  AssertEqual(Integration_RenderRaw("{% for i in range(3) %}{{ i }}{% endfor %}", forVars()), "012", "Integration: for loop range(3)")
  AssertEqual(Integration_RenderRaw("{% for i in range(1, 4) %}{{ i }}{% endfor %}", forVars()), "123", "Integration: for loop range(1,4)")

  JinjaVariant::FreeVariant(@loopList)
  ClearMap(forVars())

  ; =========================================================
  ; Test 5: Set statement
  ; =========================================================
  Protected NewMap setVars.JinjaVariant::JinjaVariant()
  AssertEqual(Integration_RenderRaw("{% set x = 10 %}{% set y = 20 %}{{ x + y }}", setVars()), "30", "Integration: set and arithmetic")
  AssertEqual(Integration_RenderRaw("{% set greeting = " + Chr(34) + "Hi" + Chr(34) + " %}{{ greeting }}, World!", setVars()), "Hi, World!", "Integration: set string then use")
  AssertEqual(Integration_RenderRaw("{% set n = 0 %}{% if n %}yes{% else %}no{% endif %}", setVars()), "no", "Integration: set 0 is falsy")

  ; =========================================================
  ; Test 6: Nested data structures
  ; =========================================================
  Protected mapV.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@mapV)
  JinjaVariant::StrVariant(@tmpV, "Bob")
  JinjaVariant::VMapSet(@mapV, "name", @tmpV)
  JinjaVariant::IntVariant(@tmpV, 30)
  JinjaVariant::VMapSet(@mapV, "age", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "engineer")
  JinjaVariant::VMapSet(@mapV, "role", @tmpV)
  Protected NewMap userVars.JinjaVariant::JinjaVariant()
  userVars("user") = mapV
  ; Do NOT FreeVariant(@mapV) here - userVars shares the MapPtr via raw copy

  AssertEqual(Integration_RenderRaw("{{ user.name }}", userVars()), "Bob", "Integration: map.name access")
  AssertEqual(Integration_RenderRaw("{{ user.age }}", userVars()), "30", "Integration: map.age access")
  AssertEqual(Integration_RenderRaw("Name: {{ user.name }}, Age: {{ user.age }}, Role: {{ user.role }}", userVars()), "Name: Bob, Age: 30, Role: engineer", "Integration: multiple map accesses")

  JinjaVariant::FreeVariant(@mapV)
  ClearMap(userVars())

  ; =========================================================
  ; Test 7: Filters in templates
  ; =========================================================
  Protected NewMap filterVars.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hello world")
  filterVars("msg") = tmpV

  AssertEqual(Integration_RenderRaw("{{ msg|upper }}", filterVars()), "HELLO WORLD", "Integration: filter upper in template")
  AssertEqual(Integration_RenderRaw("{{ msg|title }}", filterVars()), "Hello World", "Integration: filter title in template")
  AssertEqual(Integration_RenderRaw("{{ msg|length }}", filterVars()), "11", "Integration: filter length in template")
  AssertEqual(Integration_RenderRaw("{{ msg|upper|reverse }}", filterVars()), "DLROW OLLEH", "Integration: filter chaining upper|reverse")
  AssertEqual(Integration_RenderRaw("{{ msg|replace(" + Chr(34) + "world" + Chr(34) + "," + Chr(34) + "earth" + Chr(34) + ") }}", filterVars()), "hello earth", "Integration: filter replace in template")

  ; =========================================================
  ; Test 8: Combining multiple features
  ; =========================================================
  Protected NewMap multiVars.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "alice")
  multiVars("username") = tmpV
  JinjaVariant::BoolVariant(@tmpV, #True)
  multiVars("logged_in") = tmpV

  Protected multiTpl.s = "{% if logged_in %}Welcome, {{ username|capitalize }}!{% else %}Please log in.{% endif %}"
  AssertEqual(Integration_RenderRaw(multiTpl, multiVars()), "Welcome, Alice!", "Integration: if + variable + filter")

  JinjaVariant::BoolVariant(@tmpV, #False)
  multiVars("logged_in") = tmpV
  AssertEqual(Integration_RenderRaw(multiTpl, multiVars()), "Please log in.", "Integration: if false branch")

  ; =========================================================
  ; Test 9: List rendering with filters
  ; =========================================================
  Protected listWithFilter.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@listWithFilter)
  JinjaVariant::StrVariant(@itemV, "foo")
  JinjaVariant::VListAdd(@listWithFilter, @itemV)
  JinjaVariant::StrVariant(@itemV, "bar")
  JinjaVariant::VListAdd(@listWithFilter, @itemV)
  JinjaVariant::StrVariant(@itemV, "baz")
  JinjaVariant::VListAdd(@listWithFilter, @itemV)
  Protected NewMap listFVars.JinjaVariant::JinjaVariant()
  listFVars("words") = listWithFilter
  ; Do NOT FreeVariant here - listFVars shares the ListPtr via raw copy

  AssertEqual(Integration_RenderRaw("{{ words|length }}", listFVars()), "3", "Integration: list|length filter")
  AssertEqual(Integration_RenderRaw("{% for w in words %}{{ w|upper }}{% if not loop.last %},{% endif %}{% endfor %}", listFVars()), "FOO,BAR,BAZ", "Integration: for loop with filter and loop.last")

  JinjaVariant::FreeVariant(@listWithFilter)
  ClearMap(listFVars())

  ; =========================================================
  ; Test 10: HTML auto-escaping end-to-end
  ; =========================================================
  Protected NewMap htmlVars.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "<script>alert('xss')</script>")
  htmlVars("user_input") = tmpV
  ; With autoescape ON, dangerous content is neutralized
  AssertEqual(Integration_Render("{{ user_input }}", htmlVars()), "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;", "Integration: XSS prevention via autoescape")

  ; safe filter bypasses escape
  AssertEqual(Integration_Render("{{ user_input|safe }}", htmlVars()), "<script>alert('xss')</script>", "Integration: safe filter bypasses autoescape")

  ; =========================================================
  ; Test 11: DictLoader-based template rendering
  ; =========================================================
  Protected NewMap loaderVars.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "DictLoader World")
  loaderVars("msg") = tmpV
  AssertEqual(Integration_RenderTemplate("greet.html", "Hello, {{ msg }}!", loaderVars()), "Hello, DictLoader World!", "Integration: DictLoader renders template")

  ; =========================================================
  ; Test 12: Nested if inside for loop
  ; =========================================================
  Protected nestedList.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@nestedList)
  Protected numV.JinjaVariant::JinjaVariant
  JinjaVariant::IntVariant(@numV, 1)
  JinjaVariant::VListAdd(@nestedList, @numV)
  JinjaVariant::IntVariant(@numV, 2)
  JinjaVariant::VListAdd(@nestedList, @numV)
  JinjaVariant::IntVariant(@numV, 3)
  JinjaVariant::VListAdd(@nestedList, @numV)
  JinjaVariant::IntVariant(@numV, 4)
  JinjaVariant::VListAdd(@nestedList, @numV)
  Protected NewMap numVars.JinjaVariant::JinjaVariant()
  numVars("nums") = nestedList
  ; Do NOT FreeVariant here - numVars shares the ListPtr via raw copy

  AssertEqual(Integration_RenderRaw("{% for n in nums %}{% if n > 2 %}{{ n }}{% endif %}{% endfor %}", numVars()), "34", "Integration: if inside for loop")

  JinjaVariant::FreeVariant(@nestedList)
  ClearMap(numVars())

  ; =========================================================
  ; Test 13: Arithmetic and comparison expressions
  ; =========================================================
  Protected NewMap exprVars.JinjaVariant::JinjaVariant()
  JinjaVariant::IntVariant(@tmpV, 7)
  exprVars("x") = tmpV
  JinjaVariant::IntVariant(@tmpV, 3)
  exprVars("y") = tmpV

  AssertEqual(Integration_RenderRaw("{{ x + y }}", exprVars()), "10", "Integration: x+y arithmetic")
  AssertEqual(Integration_RenderRaw("{{ x - y }}", exprVars()), "4", "Integration: x-y arithmetic")
  AssertEqual(Integration_RenderRaw("{{ x * y }}", exprVars()), "21", "Integration: x*y arithmetic")
  AssertEqual(Integration_RenderRaw("{% if x > y %}bigger{% else %}smaller{% endif %}", exprVars()), "bigger", "Integration: comparison x > y")
  AssertEqual(Integration_RenderRaw("{% if x == 7 %}seven{% endif %}", exprVars()), "seven", "Integration: equality comparison")

  ; =========================================================
  ; Test 14: Boolean logic in conditions
  ; =========================================================
  Protected NewMap boolVars.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #True)
  boolVars("a") = tmpV
  JinjaVariant::BoolVariant(@tmpV, #False)
  boolVars("b") = tmpV

  AssertEqual(Integration_RenderRaw("{% if a and b %}yes{% else %}no{% endif %}", boolVars()), "no", "Integration: a and b -> no")
  AssertEqual(Integration_RenderRaw("{% if a or b %}yes{% else %}no{% endif %}", boolVars()), "yes", "Integration: a or b -> yes")
  AssertEqual(Integration_RenderRaw("{% if not b %}yes{% else %}no{% endif %}", boolVars()), "yes", "Integration: not b -> yes")

  ; =========================================================
  ; Test 15: String concatenation operator ~
  ; =========================================================
  Protected NewMap catVars.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "Hello")
  catVars("a") = tmpV
  JinjaVariant::StrVariant(@tmpV, "World")
  catVars("b") = tmpV
  AssertEqual(Integration_RenderRaw("{{ a ~ " + Chr(34) + " " + Chr(34) + " ~ b }}", catVars()), "Hello World", "Integration: string concat operator ~")

  ; =========================================================
  ; Test 16: Comments are ignored
  ; =========================================================
  Protected NewMap cmtVars.JinjaVariant::JinjaVariant()
  AssertEqual(Integration_RenderRaw("{# This is a comment #}Hello", cmtVars()), "Hello", "Integration: comment is stripped")
  AssertEqual(Integration_RenderRaw("Before{# comment #}After", cmtVars()), "BeforeAfter", "Integration: inline comment stripped")

  ; =========================================================
  ; Test 17: JinjaEnv::RenderString public API (end-to-end)
  ; =========================================================
  Protected *apiEnv.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *apiEnv\Autoescape = #False
  Protected NewMap apiVars.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "PureBasic")
  apiVars("lang") = tmpV
  AssertEqual(JinjaEnv::RenderString(*apiEnv, "Hello {{ lang }}!", apiVars()), "Hello PureBasic!", "Integration: JinjaEnv::RenderString API works")

  ; Test with filter
  AssertEqual(JinjaEnv::RenderString(*apiEnv, "{{ lang|upper }}", apiVars()), "PUREBASIC", "Integration: RenderString with filter")

  ; Test with autoescape
  *apiEnv\Autoescape = #True
  JinjaVariant::StrVariant(@tmpV, "<b>bold</b>")
  apiVars("html") = tmpV
  AssertEqual(JinjaEnv::RenderString(*apiEnv, "{{ html }}", apiVars()), "&lt;b&gt;bold&lt;/b&gt;", "Integration: RenderString with autoescape")

  JinjaEnv::FreeEnvironment(*apiEnv)

  ; =========================================================
  ; Test 18: RenderTemplate auto-resolves inheritance
  ; =========================================================
  Protected *inhEnv.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *inhEnv\Autoescape = #False
  Protected *loader.JinjaLoader::TemplateLoader = JinjaLoader::CreateDictLoader()
  JinjaLoader::DictLoaderAdd(*loader, "base.html", "Title: {% block title %}Default{% endblock %} Body: {% block body %}Default Body{% endblock %}")
  JinjaLoader::DictLoaderAdd(*loader, "child.html", "{% extends " + Chr(34) + "base.html" + Chr(34) + " %}{% block title %}Child Title{% endblock %}{% block body %}Child Body{% endblock %}")
  JinjaEnv::SetLoader(*inhEnv, *loader)

  Protected NewMap inhVars.JinjaVariant::JinjaVariant()
  Protected inhResult.s = JinjaEnv::RenderTemplate(*inhEnv, "child.html", inhVars())
  AssertTrue(Bool(FindString(inhResult, "Child Title") > 0), "Integration: RenderTemplate auto-resolves extends (title)")
  AssertTrue(Bool(FindString(inhResult, "Child Body") > 0), "Integration: RenderTemplate auto-resolves extends (body)")
  AssertFalse(Bool(FindString(inhResult, "Default Body") > 0), "Integration: RenderTemplate parent defaults overridden")

  JinjaEnv::FreeEnvironment(*inhEnv)

  PrintN("")
EndProcedure
