; ============================================================================
; PureJinja - TestWhitespace.pbi
; Tests for Jinja whitespace control strip markers:
;   {{- x }}  strip whitespace before variable tag
;   {{ x -}}  strip whitespace after variable tag
;   {%- ... -%}  strip whitespace before/after block tag
;   {#- ... -#}  strip whitespace before/after comment
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Helper: render with autoescape OFF
; ---------------------------------------------------------------------------
Procedure.s WS_Render(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False
  Protected result.s = JinjaEnv::RenderString(*env, templateStr, variables())
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn result
EndProcedure

; ---------------------------------------------------------------------------
Procedure RunWhitespaceTests()
  PrintN("--- Whitespace Control Tests ---")

  Protected tmpV.JinjaVariant::JinjaVariant

  ; ===========================================================================
  ; Section 1: Variable tag strip markers
  ; ===========================================================================

  Protected NewMap vars_x.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "hi")
  vars_x("x") = tmpV

  ; No strip — whitespace preserved on both sides
  AssertEqual(WS_Render("  {{ x }}  ", vars_x()), "  hi  ", "WS 01: no strip - whitespace preserved")

  ; Strip before ({{-)
  AssertEqual(WS_Render("  {{- x }}  ", vars_x()), "hi  ", "WS 02: {{- strip before variable")

  ; Strip after (-}})
  AssertEqual(WS_Render("  {{ x -}}  ", vars_x()), "  hi", "WS 03: -}} strip after variable")

  ; Strip both
  AssertEqual(WS_Render("  {{- x -}}  ", vars_x()), "hi", "WS 04: {{- -}} strip both sides of variable")

  ; Strip before with newline
  AssertEqual(WS_Render("line1" + Chr(10) + "  {{- x }}", vars_x()), "line1hi", "WS 05: {{- strips newline+spaces before variable")

  ; Strip after with newline
  AssertEqual(WS_Render("{{ x -}}" + Chr(10) + "  line2", vars_x()), "hiline2", "WS 06: -}} strips newline+spaces after variable")

  ; ===========================================================================
  ; Section 2: Block tag strip markers
  ; ===========================================================================

  Protected NewMap vars_cond.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars_cond("flag") = tmpV

  ; Strip before block begin: leading spaces removed
  AssertEqual(WS_Render("  {%- if flag %}yes{% endif %}", vars_cond()), "yes", "WS 07: {%- strips whitespace before if tag")

  ; Strip after block end: trailing spaces of following text removed
  AssertEqual(WS_Render("{% if flag -%}  yes{% endif %}", vars_cond()), "yes", "WS 08: -%} strips whitespace after block tag")

  ; Strip all whitespace around a full if block
  ; "  {%- if flag -%}  yes  {%- endif -%}  "
  ; {%- strips "  " before if → empty
  ; -%} after if strips "  " before "yes  " → "yes  "
  ; {%- before endif strips trailing "  " from "yes  " → "yes"
  ; -%} after endif strips "  " at end → empty
  ; Result: "yes"
  AssertEqual(WS_Render("  {%- if flag -%}  yes  {%- endif -%}  ", vars_cond()), "yes", "WS 09: strip all whitespace around if block")

  ; ===========================================================================
  ; Section 3: set tag — strip newline after (silent assignment pattern)
  ; ===========================================================================

  Protected NewMap vars_set.JinjaVariant::JinjaVariant()
  ; "line1\n  {% set x = 1 -%}\n  next" → "line1\n  next"
  ; The -%} strips the \n and spaces after the set tag, so "  " before set stays
  AssertEqual(WS_Render("line1" + Chr(10) + "  {% set x = 1 -%}" + Chr(10) + "  next", vars_set()), "line1" + Chr(10) + "  next", "WS 10: -%} strips newline after set tag")

  ; ===========================================================================
  ; Section 4: Strip before/after with surrounding non-whitespace content
  ; ===========================================================================

  Protected NewMap vars_greet.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "World")
  vars_greet("name") = tmpV

  ; Normal variable — no strip
  AssertEqual(WS_Render("Hello, {{ name }}!", vars_greet()), "Hello, World!", "WS 11: normal variable no strip")

  ; Strip before only
  AssertEqual(WS_Render("Hello,   {{- name }}!", vars_greet()), "Hello,World!", "WS 12: {{- strips spaces before, after intact")

  ; Strip after only
  AssertEqual(WS_Render("Hello, {{ name -}}   !", vars_greet()), "Hello, World!", "WS 13: -}} strips spaces after, before intact")

  ; ===========================================================================
  ; Section 5: Comment strip markers  {#- ... -#}
  ; ===========================================================================

  Protected NewMap vars_empty.JinjaVariant::JinjaVariant()

  ; Normal comment — whitespace from both sides preserved
  AssertEqual(WS_Render("before  {# comment #}  after", vars_empty()), "before    after", "WS 14: normal comment - whitespace preserved")

  ; Strip before comment ({#-)
  AssertEqual(WS_Render("before  {#- comment #}  after", vars_empty()), "before  after", "WS 15: {#- strips whitespace before comment")

  ; Strip after comment (-#})
  AssertEqual(WS_Render("before  {# comment -#}  after", vars_empty()), "before  after", "WS 16: -#} strips whitespace after comment")

  ; Strip both sides of comment
  AssertEqual(WS_Render("before  {#- comment -#}  after", vars_empty()), "beforeafter", "WS 17: {#- -#} strips whitespace on both sides of comment")

  ; ===========================================================================
  ; Section 6: Multiple strip tags in sequence
  ; ===========================================================================

  Protected NewMap vars_multi.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "A")
  vars_multi("a") = tmpV
  JinjaVariant::StrVariant(@tmpV, "B")
  vars_multi("b") = tmpV

  ; Two variables with strip markers — all whitespace removed between them
  AssertEqual(WS_Render("  {{- a -}}   {{- b -}}  ", vars_multi()), "AB", "WS 18: multiple strip markers - no whitespace between")

  ; ===========================================================================
  ; Section 7: For loop with strip markers
  ; ===========================================================================

  Protected itemsList.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@itemsList)
  JinjaVariant::StrVariant(@tmpV, "one")
  JinjaVariant::VListAdd(@itemsList, @tmpV)
  JinjaVariant::StrVariant(@tmpV, "two")
  JinjaVariant::VListAdd(@itemsList, @tmpV)
  JinjaVariant::StrVariant(@tmpV, "three")
  JinjaVariant::VListAdd(@itemsList, @tmpV)
  Protected NewMap vars_for.JinjaVariant::JinjaVariant()
  vars_for("items") = itemsList

  ; Without strip: newlines appear around block tags
  Protected tpl_for_nostrip.s = "{% for item in items %}" + Chr(10) + "{{ item }}" + Chr(10) + "{% endfor %}"
  ; Each iteration: "\none\n", "\ntwo\n", "\nthree\n"
  AssertEqual(WS_Render(tpl_for_nostrip, vars_for()), Chr(10) + "one" + Chr(10) + Chr(10) + "two" + Chr(10) + Chr(10) + "three" + Chr(10), "WS 19: for loop without strip - newlines present")

  ; With strip on both loop tags: all newlines around loop tags stripped
  ; {%- for -%} strips leading \n after -> body is: {{ item }}\n
  ; {%- endfor -%} strips trailing \n before endfor and trailing of whole template
  ; Body per iteration: item + "\n" (since {%- endfor strips preceding \n from body)
  ; Wait: body text is "\n{{ item }}\n", -%} strips leading \n -> "{{ item }}\n"
  ;       {%- endfor strips trailing \n -> "{{ item }}"
  ; So each iteration renders just the item value: "one", "two", "three" -> "onetwothree"
  Protected tpl_for_strip.s = "{%- for item in items -%}" + Chr(10) + "{{ item }}" + Chr(10) + "{%- endfor -%}"
  AssertEqual(WS_Render(tpl_for_strip, vars_for()), "onetwothree", "WS 20: for loop with strip markers - no whitespace")

  JinjaVariant::FreeVariant(@itemsList)

  PrintN("")
EndProcedure
