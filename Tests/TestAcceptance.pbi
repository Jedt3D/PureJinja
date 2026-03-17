; ============================================================================
; PureJinja - TestAcceptance.pbi
; Acceptance tests derived from the 55 HTML template files in templates/
; Each test isolates the Jinja2 feature from the template and verifies output.
; Uses JinjaEnv::RenderString() public API (autoescape OFF unless noted).
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Helper: render template string with autoescape OFF
; (named Acc_ to avoid conflicts with Integration_ helpers)
; ---------------------------------------------------------------------------
Procedure.s Acc_Render(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False
  Protected result.s = JinjaEnv::RenderString(*env, templateStr, variables())
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn result
EndProcedure

; ---------------------------------------------------------------------------
; Helper: render template string with autoescape ON
; ---------------------------------------------------------------------------
Procedure.s Acc_RenderEscape(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #True
  Protected result.s = JinjaEnv::RenderString(*env, templateStr, variables())
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn result
EndProcedure

; ---------------------------------------------------------------------------
Procedure RunAcceptanceTests()
  PrintN("--- Acceptance Tests ---")

  Protected tmpV.JinjaVariant::JinjaVariant
  Protected itemV.JinjaVariant::JinjaVariant

  ; ==========================================================================
  ; Category: Variables (templates 01-05)
  ; ==========================================================================

  ; --- 01_hello.html: simple string variable ---
  Protected NewMap vars01.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "World")
  vars01("name") = tmpV
  AssertEqual(Acc_Render("Hello, {{ name }}!", vars01()), "Hello, World!", "Accept 01: hello - simple variable")

  ; --- 02_multiple_vars.html: two variables in one expression ---
  Protected NewMap vars02.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "Jane")
  vars02("first") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Doe")
  vars02("last") = tmpV
  AssertEqual(Acc_Render("{{ first }} {{ last }}", vars02()), "Jane Doe", "Accept 02: multiple_vars - two variables")

  ; --- 03_missing_var.html: undefined variable renders as empty string ---
  Protected NewMap vars03.JinjaVariant::JinjaVariant()
  AssertEqual(Acc_Render("Hello, {{ missing_name }}!", vars03()), "Hello, !", "Accept 03: missing_var - undefined renders empty")

  ; --- 04_integer_var.html: integer variable ---
  Protected NewMap vars04.JinjaVariant::JinjaVariant()
  JinjaVariant::IntVariant(@tmpV, 42)
  vars04("count") = tmpV
  AssertEqual(Acc_Render("{{ count }} items in stock", vars04()), "42 items in stock", "Accept 04: integer_var - integer variable")

  ; --- 05_nested_access.html: map/object dot notation ---
  Protected userMap05.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@userMap05)
  JinjaVariant::StrVariant(@tmpV, "Alice")
  JinjaVariant::VMapSet(@userMap05, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "alice@example.com")
  JinjaVariant::VMapSet(@userMap05, "email", @tmpV)
  Protected NewMap vars05.JinjaVariant::JinjaVariant()
  vars05("user") = userMap05
  AssertEqual(Acc_Render("{{ user.name }} ({{ user.email }})", vars05()), "Alice (alice@example.com)", "Accept 05: nested_access - dot notation")
  JinjaVariant::FreeVariant(@userMap05)

  ; ==========================================================================
  ; Category: Filters (templates 06-15)
  ; ==========================================================================

  ; --- 06_upper.html: |upper filter ---
  Protected NewMap vars06.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hello")
  vars06("name") = tmpV
  AssertEqual(Acc_Render("{{ name|upper }}", vars06()), "HELLO", "Accept 06: upper - filter upper")

  ; --- 07_lower.html: |lower filter (variable is NAME in caps) ---
  Protected NewMap vars07.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "HELLO WORLD")
  vars07("NAME") = tmpV
  AssertEqual(Acc_Render("{{ NAME|lower }}", vars07()), "hello world", "Accept 07: lower - filter lower")

  ; --- 08_title.html: |title filter ---
  Protected NewMap vars08.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hello world")
  vars08("text") = tmpV
  AssertEqual(Acc_Render("{{ text|title }}", vars08()), "Hello World", "Accept 08: title - filter title")

  ; --- 09_capitalize.html: |capitalize filter ---
  Protected NewMap vars09.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hello world")
  vars09("text") = tmpV
  AssertEqual(Acc_Render("{{ text|capitalize }}", vars09()), "Hello world", "Accept 09: capitalize - filter capitalize")

  ; --- 10_trim.html: |trim filter ---
  Protected NewMap vars10.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "  hello  ")
  vars10("text") = tmpV
  AssertEqual(Acc_Render("[{{ text|trim }}]", vars10()), "[hello]", "Accept 10: trim - filter trim")

  ; --- 11_length.html: |length filter on string ---
  Protected NewMap vars11.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hello")
  vars11("text") = tmpV
  AssertEqual(Acc_Render("{{ text|length }}", vars11()), "5", "Accept 11: length - filter length on string")

  ; --- 12_default.html: |default filter on missing variable ---
  Protected NewMap vars12.JinjaVariant::JinjaVariant()
  ; 'missing' is not set in vars12
  AssertEqual(Acc_Render("{{ missing|default(" + Chr(34) + "N/A" + Chr(34) + ") }}", vars12()), "N/A", "Accept 12: default - filter default for missing var")

  ; --- 13_replace.html: |replace filter ---
  Protected NewMap vars13.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hello world")
  vars13("text") = tmpV
  AssertEqual(Acc_Render("{{ text|replace(" + Chr(34) + "world" + Chr(34) + "," + Chr(34) + "Xojo" + Chr(34) + ") }}", vars13()), "hello Xojo", "Accept 13: replace - filter replace")

  ; --- 14_first_last.html: |first and |last filters on string ---
  Protected NewMap vars14.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hello")
  vars14("text") = tmpV
  AssertEqual(Acc_Render("{{ text|first }}", vars14()), "h", "Accept 14a: first_last - filter first")
  AssertEqual(Acc_Render("{{ text|last }}", vars14()), "o", "Accept 14b: first_last - filter last")

  ; --- 15_chained.html: chained filters |trim|upper ---
  Protected NewMap vars15.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "  hello world  ")
  vars15("name") = tmpV
  AssertEqual(Acc_Render("{{ name|trim|upper }}", vars15()), "HELLO WORLD", "Accept 15: chained - filter trim|upper chained")

  ; ==========================================================================
  ; Category: Conditionals (templates 16-22)
  ; ==========================================================================

  ; --- 16_if_true.html: {% if %} when condition is true ---
  Protected NewMap vars16.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars16("logged_in") = tmpV
  AssertEqual(Acc_Render("{% if logged_in %}Welcome back!{% endif %}", vars16()), "Welcome back!", "Accept 16a: if_true - if true renders body")

  ; false branch: body is skipped
  JinjaVariant::BoolVariant(@tmpV, #False)
  vars16("logged_in") = tmpV
  AssertEqual(Acc_Render("{% if logged_in %}Welcome back!{% endif %}", vars16()), "", "Accept 16b: if_true - if false skips body")

  ; --- 17_if_not.html: {% if not %} ---
  Protected NewMap vars17.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #False)
  vars17("logged_in") = tmpV
  AssertEqual(Acc_Render("{% if not logged_in %}Please log in.{% endif %}", vars17()), "Please log in.", "Accept 17a: if_not - not false renders body")

  JinjaVariant::BoolVariant(@tmpV, #True)
  vars17("logged_in") = tmpV
  AssertEqual(Acc_Render("{% if not logged_in %}Please log in.{% endif %}", vars17()), "", "Accept 17b: if_not - not true skips body")

  ; --- 18_if_else.html: {% if/else %} ---
  Protected NewMap vars18.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars18("logged_in") = tmpV
  AssertEqual(Acc_Render("{% if logged_in %}Welcome!{% else %}Guest{% endif %}", vars18()), "Welcome!", "Accept 18a: if_else - true branch")

  JinjaVariant::BoolVariant(@tmpV, #False)
  vars18("logged_in") = tmpV
  AssertEqual(Acc_Render("{% if logged_in %}Welcome!{% else %}Guest{% endif %}", vars18()), "Guest", "Accept 18b: if_else - else branch")

  ; --- 19_if_elif.html: {% if/elif/else %} ---
  Protected NewMap vars19.JinjaVariant::JinjaVariant()
  Protected ifElifTpl19.s = "{% if role == " + Chr(34) + "admin" + Chr(34) + " %}Admin{% elif role == " + Chr(34) + "user" + Chr(34) + " %}User{% else %}Guest{% endif %}"

  JinjaVariant::StrVariant(@tmpV, "admin")
  vars19("role") = tmpV
  AssertEqual(Acc_Render(ifElifTpl19, vars19()), "Admin", "Accept 19a: if_elif - admin branch")

  JinjaVariant::StrVariant(@tmpV, "user")
  vars19("role") = tmpV
  AssertEqual(Acc_Render(ifElifTpl19, vars19()), "User", "Accept 19b: if_elif - user branch")

  JinjaVariant::StrVariant(@tmpV, "guest")
  vars19("role") = tmpV
  AssertEqual(Acc_Render(ifElifTpl19, vars19()), "Guest", "Accept 19c: if_elif - else branch")

  ; --- 20_if_comparison.html: {% if age >= 18 %} ---
  Protected NewMap vars20.JinjaVariant::JinjaVariant()
  JinjaVariant::IntVariant(@tmpV, 20)
  vars20("age") = tmpV
  AssertEqual(Acc_Render("{% if age >= 18 %}Adult{% else %}Minor{% endif %}", vars20()), "Adult", "Accept 20a: if_comparison - age 20 is adult")

  JinjaVariant::IntVariant(@tmpV, 16)
  vars20("age") = tmpV
  AssertEqual(Acc_Render("{% if age >= 18 %}Adult{% else %}Minor{% endif %}", vars20()), "Minor", "Accept 20b: if_comparison - age 16 is minor")

  ; --- 21_if_in.html: {% if "admin" in roles %} ---
  Protected rolesList21.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@rolesList21)
  JinjaVariant::StrVariant(@itemV, "admin")
  JinjaVariant::VListAdd(@rolesList21, @itemV)
  JinjaVariant::StrVariant(@itemV, "editor")
  JinjaVariant::VListAdd(@rolesList21, @itemV)
  Protected NewMap vars21.JinjaVariant::JinjaVariant()
  vars21("roles") = rolesList21
  AssertEqual(Acc_Render("{% if " + Chr(34) + "admin" + Chr(34) + " in roles %}Has admin role{% else %}No admin role{% endif %}", vars21()), "Has admin role", "Accept 21a: if_in - admin in list")

  ; without admin
  Protected rolesNoAdmin21.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@rolesNoAdmin21)
  JinjaVariant::StrVariant(@itemV, "editor")
  JinjaVariant::VListAdd(@rolesNoAdmin21, @itemV)
  Protected NewMap vars21b.JinjaVariant::JinjaVariant()
  vars21b("roles") = rolesNoAdmin21
  AssertEqual(Acc_Render("{% if " + Chr(34) + "admin" + Chr(34) + " in roles %}Has admin role{% else %}No admin role{% endif %}", vars21b()), "No admin role", "Accept 21b: if_in - admin not in list")

  JinjaVariant::FreeVariant(@rolesList21)
  JinjaVariant::FreeVariant(@rolesNoAdmin21)

  ; --- 22_if_and_or.html: {% if is_active and is_verified %} ---
  Protected NewMap vars22.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars22("is_active") = tmpV
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars22("is_verified") = tmpV
  AssertEqual(Acc_Render("{% if is_active and is_verified %}Active & Verified{% else %}Inactive{% endif %}", vars22()), "Active & Verified", "Accept 22a: if_and_or - both true")

  JinjaVariant::BoolVariant(@tmpV, #True)
  vars22("is_active") = tmpV
  JinjaVariant::BoolVariant(@tmpV, #False)
  vars22("is_verified") = tmpV
  AssertEqual(Acc_Render("{% if is_active and is_verified %}Active & Verified{% else %}Inactive{% endif %}", vars22()), "Inactive", "Accept 22b: if_and_or - one false")

  ; ==========================================================================
  ; Category: Loops (templates 23-31)
  ; ==========================================================================

  ; --- 23_for_simple.html: basic for loop ---
  Protected itemsList23.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList23)
  JinjaVariant::StrVariant(@itemV, "apple")
  JinjaVariant::VListAdd(@itemsList23, @itemV)
  JinjaVariant::StrVariant(@itemV, "banana")
  JinjaVariant::VListAdd(@itemsList23, @itemV)
  JinjaVariant::StrVariant(@itemV, "cherry")
  JinjaVariant::VListAdd(@itemsList23, @itemV)
  Protected NewMap vars23.JinjaVariant::JinjaVariant()
  vars23("items") = itemsList23
  AssertEqual(Acc_Render("{% for item in items %}{{ item }} {% endfor %}", vars23()), "apple banana cherry ", "Accept 23: for_simple - basic for loop")
  JinjaVariant::FreeVariant(@itemsList23)

  ; --- 24_for_index.html: loop.index ---
  Protected itemsList24.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList24)
  JinjaVariant::StrVariant(@itemV, "a")
  JinjaVariant::VListAdd(@itemsList24, @itemV)
  JinjaVariant::StrVariant(@itemV, "b")
  JinjaVariant::VListAdd(@itemsList24, @itemV)
  JinjaVariant::StrVariant(@itemV, "c")
  JinjaVariant::VListAdd(@itemsList24, @itemV)
  Protected NewMap vars24.JinjaVariant::JinjaVariant()
  vars24("items") = itemsList24
  AssertEqual(Acc_Render("{% for item in items %}{{ loop.index }}.{{ item }} {% endfor %}", vars24()), "1.a 2.b 3.c ", "Accept 24: for_index - loop.index")
  JinjaVariant::FreeVariant(@itemsList24)

  ; --- 25_for_first_last.html: loop.first and loop.last ---
  Protected itemsList25.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList25)
  JinjaVariant::StrVariant(@itemV, "x")
  JinjaVariant::VListAdd(@itemsList25, @itemV)
  JinjaVariant::StrVariant(@itemV, "y")
  JinjaVariant::VListAdd(@itemsList25, @itemV)
  JinjaVariant::StrVariant(@itemV, "z")
  JinjaVariant::VListAdd(@itemsList25, @itemV)
  Protected NewMap vars25.JinjaVariant::JinjaVariant()
  vars25("items") = itemsList25
  Protected tpl25.s = "{% for item in items %}{% if loop.first %}[{% endif %}{{ item }}{% if loop.last %}]{% endif %}{% if not loop.last %},{% endif %}{% endfor %}"
  AssertEqual(Acc_Render(tpl25, vars25()), "[x,y,z]", "Accept 25: for_first_last - loop.first/last")
  JinjaVariant::FreeVariant(@itemsList25)

  ; --- 26_for_dict.html: iterating list of maps ---
  Protected usersList26.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@usersList26)

  Protected user26a.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@user26a)
  JinjaVariant::StrVariant(@tmpV, "Alice")
  JinjaVariant::VMapSet(@user26a, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "admin")
  JinjaVariant::VMapSet(@user26a, "role", @tmpV)
  JinjaVariant::VListAdd(@usersList26, @user26a)
  JinjaVariant::FreeVariant(@user26a)

  Protected user26b.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@user26b)
  JinjaVariant::StrVariant(@tmpV, "Bob")
  JinjaVariant::VMapSet(@user26b, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "editor")
  JinjaVariant::VMapSet(@user26b, "role", @tmpV)
  JinjaVariant::VListAdd(@usersList26, @user26b)
  JinjaVariant::FreeVariant(@user26b)

  Protected NewMap vars26.JinjaVariant::JinjaVariant()
  vars26("users") = usersList26
  AssertEqual(Acc_Render("{% for user in users %}{{ user.name }}:{{ user.role }} {% endfor %}", vars26()), "Alice:admin Bob:editor ", "Accept 26: for_dict - iterate list of maps")
  JinjaVariant::FreeVariant(@usersList26)

  ; --- 27_for_else.html: for/else with empty list ---
  Protected emptyList27.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@emptyList27)
  Protected NewMap vars27.JinjaVariant::JinjaVariant()
  vars27("items") = emptyList27
  AssertEqual(Acc_Render("{% for item in items %}{{ item }}{% else %}No items found.{% endfor %}", vars27()), "No items found.", "Accept 27a: for_else - empty list renders else")
  JinjaVariant::FreeVariant(@emptyList27)

  ; for/else with non-empty list: else skipped
  Protected itemsList27b.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList27b)
  JinjaVariant::StrVariant(@itemV, "one")
  JinjaVariant::VListAdd(@itemsList27b, @itemV)
  Protected NewMap vars27b.JinjaVariant::JinjaVariant()
  vars27b("items") = itemsList27b
  AssertEqual(Acc_Render("{% for item in items %}{{ item }}{% else %}No items found.{% endfor %}", vars27b()), "one", "Accept 27b: for_else - non-empty list skips else")
  JinjaVariant::FreeVariant(@itemsList27b)

  ; --- 28_for_nested.html: nested for loops ---
  Protected groupsList28.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@groupsList28)

  Protected grp28a.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@grp28a)
  JinjaVariant::StrVariant(@itemV, "a1")
  JinjaVariant::VListAdd(@grp28a, @itemV)
  JinjaVariant::StrVariant(@itemV, "a2")
  JinjaVariant::VListAdd(@grp28a, @itemV)
  JinjaVariant::VListAdd(@groupsList28, @grp28a)
  JinjaVariant::FreeVariant(@grp28a)

  Protected grp28b.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@grp28b)
  JinjaVariant::StrVariant(@itemV, "b1")
  JinjaVariant::VListAdd(@grp28b, @itemV)
  JinjaVariant::VListAdd(@groupsList28, @grp28b)
  JinjaVariant::FreeVariant(@grp28b)

  Protected NewMap vars28.JinjaVariant::JinjaVariant()
  vars28("groups") = groupsList28
  AssertEqual(Acc_Render("{% for group in groups %}[{% for item in group %}{{ item }} {% endfor %}]{% endfor %}", vars28()), "[a1 a2 ][b1 ]", "Accept 28: for_nested - nested for loops")
  JinjaVariant::FreeVariant(@groupsList28)

  ; --- 29_for_filter.html: apply filter inside for loop ---
  Protected itemsList29.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList29)
  JinjaVariant::StrVariant(@itemV, "foo")
  JinjaVariant::VListAdd(@itemsList29, @itemV)
  JinjaVariant::StrVariant(@itemV, "bar")
  JinjaVariant::VListAdd(@itemsList29, @itemV)
  Protected NewMap vars29.JinjaVariant::JinjaVariant()
  vars29("items") = itemsList29
  AssertEqual(Acc_Render("{% for item in items %}{{ item|upper }} {% endfor %}", vars29()), "FOO BAR ", "Accept 29: for_filter - filter inside loop")
  JinjaVariant::FreeVariant(@itemsList29)

  ; --- 30_for_conditional.html: if inside for to skip items ---
  Protected itemsList30.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList30)
  JinjaVariant::StrVariant(@itemV, "keep")
  JinjaVariant::VListAdd(@itemsList30, @itemV)
  JinjaVariant::StrVariant(@itemV, "skip")
  JinjaVariant::VListAdd(@itemsList30, @itemV)
  JinjaVariant::StrVariant(@itemV, "also")
  JinjaVariant::VListAdd(@itemsList30, @itemV)
  Protected NewMap vars30.JinjaVariant::JinjaVariant()
  vars30("items") = itemsList30
  AssertEqual(Acc_Render("{% for item in items %}{% if item != " + Chr(34) + "skip" + Chr(34) + " %}{{ item }} {% endif %}{% endfor %}", vars30()), "keep also ", "Accept 30: for_conditional - if inside for skips items")
  JinjaVariant::FreeVariant(@itemsList30)

  ; --- 31_for_counter.html: loop.index0 and loop.length ---
  Protected itemsList31.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList31)
  JinjaVariant::StrVariant(@itemV, "a")
  JinjaVariant::VListAdd(@itemsList31, @itemV)
  JinjaVariant::StrVariant(@itemV, "b")
  JinjaVariant::VListAdd(@itemsList31, @itemV)
  JinjaVariant::StrVariant(@itemV, "c")
  JinjaVariant::VListAdd(@itemsList31, @itemV)
  Protected NewMap vars31.JinjaVariant::JinjaVariant()
  vars31("items") = itemsList31
  AssertEqual(Acc_Render("{% for item in items %}{{ loop.index0 }}/{{ loop.length }}:{{ item }} {% endfor %}", vars31()), "0/3:a 1/3:b 2/3:c ", "Accept 31: for_counter - loop.index0 and loop.length")
  JinjaVariant::FreeVariant(@itemsList31)

  ; ==========================================================================
  ; Category: Set (templates 32-35)
  ; ==========================================================================

  ; --- 32_for_set.html: {% set %} before for loop, used inside ---
  Protected itemsList32.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList32)
  JinjaVariant::StrVariant(@itemV, "alpha")
  JinjaVariant::VListAdd(@itemsList32, @itemV)
  JinjaVariant::StrVariant(@itemV, "beta")
  JinjaVariant::VListAdd(@itemsList32, @itemV)
  Protected NewMap vars32.JinjaVariant::JinjaVariant()
  vars32("items") = itemsList32
  AssertEqual(Acc_Render("{% set prefix = " + Chr(34) + "Item" + Chr(34) + " %}{% for item in items %}{{ prefix }}: {{ item }} {% endfor %}", vars32()), "Item: alpha Item: beta ", "Accept 32: for_set - set before loop, used inside")
  JinjaVariant::FreeVariant(@itemsList32)

  ; --- 33_set_variable.html: basic {% set %} ---
  Protected NewMap vars33.JinjaVariant::JinjaVariant()
  AssertEqual(Acc_Render("{% set greeting = " + Chr(34) + "Hello" + Chr(34) + " %}{{ greeting }}, World!", vars33()), "Hello, World!", "Accept 33: set_variable - set string variable")

  ; --- 34_set_computed.html: {% set %} with arithmetic ---
  Protected NewMap vars34.JinjaVariant::JinjaVariant()
  JinjaVariant::IntVariant(@tmpV, 5)
  vars34("price") = tmpV
  JinjaVariant::IntVariant(@tmpV, 3)
  vars34("quantity") = tmpV
  AssertEqual(Acc_Render("{% set total = price * quantity %}Total: {{ total }}", vars34()), "Total: 15", "Accept 34: set_computed - set computed value")

  ; --- 35_set_in_scope.html: set inside if block, Jinja scoping ---
  ; In Jinja2 / PureJinja, set inside block is visible in outer scope
  Protected NewMap vars35.JinjaVariant::JinjaVariant()
  Protected tpl35.s = "{% set x = " + Chr(34) + "outer" + Chr(34) + " %}{% if true %}{% set x = " + Chr(34) + "inner" + Chr(34) + " %}{{ x }}{% endif %}{{ x }}"
  AssertEqual(Acc_Render(tpl35, vars35()), "innerinner", "Accept 35: set_in_scope - inner set visible outside block")

  ; ==========================================================================
  ; Category: Escaping (templates 36-40) - autoescape ON
  ; ==========================================================================

  ; --- 36_escape_html.html: autoescape ON escapes user input ---
  Protected NewMap vars36.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "<script>alert('xss')</script>")
  vars36("user_input") = tmpV
  AssertEqual(Acc_RenderEscape("{{ user_input }}", vars36()), "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;", "Accept 36: escape_html - HTML entities escaped")

  ; --- 37_safe_markup.html: |safe filter bypasses autoescape ---
  Protected NewMap vars37.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "<strong>bold</strong>")
  vars37("safe_html") = tmpV
  AssertEqual(Acc_RenderEscape("{{ safe_html|safe }}", vars37()), "<strong>bold</strong>", "Accept 37: safe_markup - safe filter bypasses autoescape")

  ; --- 38_escape_attributes.html: escaping in attribute context ---
  Protected NewMap vars38.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "https://example.com/?a=1&b=2")
  vars38("url") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Click here")
  vars38("link_text") = tmpV
  AssertEqual(Acc_RenderEscape("{{ url }}", vars38()), "https://example.com/?a=1&amp;b=2", "Accept 38a: escape_attributes - ampersand in URL escaped")
  AssertEqual(Acc_RenderEscape("{{ link_text }}", vars38()), "Click here", "Accept 38b: escape_attributes - safe text unchanged")

  ; --- 39_double_escape_prevention.html: already-escaped content ---
  ; With autoescape ON: a normal string gets escaped. The |safe filter prevents double-escaping.
  Protected NewMap vars39.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "&lt;b&gt;bold&lt;/b&gt;")
  vars39("already_escaped") = tmpV
  ; Without |safe: autoescape would double-escape the &
  AssertEqual(Acc_RenderEscape("{{ already_escaped }}", vars39()), "&amp;lt;b&amp;gt;bold&amp;lt;/b&amp;gt;", "Accept 39a: double_escape - normal string gets re-escaped")
  ; With |safe: markup is passed through as-is (no double escaping)
  AssertEqual(Acc_RenderEscape("{{ already_escaped|safe }}", vars39()), "&lt;b&gt;bold&lt;/b&gt;", "Accept 39b: double_escape - safe prevents double-escape")

  ; --- 40_mixed_safe_unsafe.html: safe and unsafe in same template ---
  Protected NewMap vars40.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "<em>trusted</em>")
  vars40("safe_part") = tmpV
  JinjaVariant::StrVariant(@tmpV, "<script>evil()</script>")
  vars40("unsafe_part") = tmpV
  ; safe_part with |safe: rendered as-is
  AssertEqual(Acc_RenderEscape("{{ safe_part|safe }}", vars40()), "<em>trusted</em>", "Accept 40a: mixed_safe_unsafe - safe_part rendered raw")
  ; unsafe_part without |safe: escaped
  AssertEqual(Acc_RenderEscape("{{ unsafe_part }}", vars40()), "&lt;script&gt;evil()&lt;/script&gt;", "Accept 40b: mixed_safe_unsafe - unsafe_part escaped")
  ; both together
  Protected tpl40.s = "{{ safe_part|safe }} | {{ unsafe_part }}"
  AssertEqual(Acc_RenderEscape(tpl40, vars40()), "<em>trusted</em> | &lt;script&gt;evil()&lt;/script&gt;", "Accept 40c: mixed_safe_unsafe - mixed in one template")

  PrintN("")
EndProcedure
