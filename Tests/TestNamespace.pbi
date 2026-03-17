; ============================================================================
; PureJinja - TestNamespace.pbi
; Tests for namespace() global function and {% set ns.attr = value %} syntax
; ============================================================================
EnableExplicit

Procedure RunNamespaceTests()
  PrintN("--- Namespace Tests ---")

  Protected NewMap vars.JinjaVariant::JinjaVariant()

  ; =========================================================
  ; Basic namespace() creation and attribute set/get
  ; =========================================================

  ; Test 1: Create namespace and set a single integer attribute
  AssertEqual(RendererHelper_RenderNoEscape("{% set ns = namespace() %}{% set ns.x = 1 %}{{ ns.x }}", vars()), "1", "Namespace: basic set and get integer attribute")

  ; Test 2: Create namespace and set a string attribute
  Protected tpl2.s = "{% set ns = namespace() %}{% set ns.name = " + Chr(34) + "hello" + Chr(34) + " %}{{ ns.name }}"
  AssertEqual(RendererHelper_RenderNoEscape(tpl2, vars()), "hello", "Namespace: set and get string attribute")

  ; Test 3: Multiple attributes on the same namespace
  AssertEqual(RendererHelper_RenderNoEscape("{% set ns = namespace() %}{% set ns.a = 1 %}{% set ns.b = 2 %}{{ ns.a }}-{{ ns.b }}", vars()), "1-2", "Namespace: multiple attributes on same namespace")

  ; Test 4: Attribute with filter
  Protected tpl4.s = "{% set ns = namespace() %}{% set ns.name = " + Chr(34) + "hello" + Chr(34) + " %}{{ ns.name|upper }}"
  AssertEqual(RendererHelper_RenderNoEscape(tpl4, vars()), "HELLO", "Namespace: attribute with filter (upper)")

  ; =========================================================
  ; Cross-scope persistence (the key namespace use case)
  ; =========================================================

  ; Build a list of items [10, 20, 30] in the variable map
  Protected NewList items.JinjaVariant::JinjaVariant()
  AddElement(items()) : JinjaVariant::IntVariant(@items(), 10)
  AddElement(items()) : JinjaVariant::IntVariant(@items(), 20)
  AddElement(items()) : JinjaVariant::IntVariant(@items(), 30)
  JinjaVariant::NewListVariant(@vars("items"))
  ForEach items()
    JinjaVariant::VListAdd(@vars("items"), @items())
  Next

  ; Test 5: Counter incremented inside a for loop persists outside
  AssertEqual(RendererHelper_RenderNoEscape("{% set ns = namespace() %}{% set ns.count = 0 %}{% for item in items %}{% set ns.count = ns.count + 1 %}{% endfor %}{{ ns.count }}", vars()), "3", "Namespace: counter incremented in for loop persists outside")

  ; Test 6: Sum accumulator in a for loop persists outside
  AssertEqual(RendererHelper_RenderNoEscape("{% set ns = namespace() %}{% set ns.total = 0 %}{% for item in items %}{% set ns.total = ns.total + item %}{% endfor %}{{ ns.total }}", vars()), "60", "Namespace: sum accumulator in for loop persists outside")

  ; Test 7: String concatenation across loop iterations
  Protected tpl7.s = "{% set ns = namespace() %}{% set ns.out = " + Chr(34) + Chr(34) + " %}{% for item in items %}{% set ns.out = ns.out ~ item ~ " + Chr(34) + "," + Chr(34) + " %}{% endfor %}{{ ns.out }}"
  AssertEqual(RendererHelper_RenderNoEscape(tpl7, vars()), "10,20,30,", "Namespace: string concatenation across loop iterations")

  ; Test 8: Namespace persists across if block
  AssertEqual(RendererHelper_RenderNoEscape("{% set ns = namespace() %}{% set ns.flag = 0 %}{% if true %}{% set ns.flag = 99 %}{% endif %}{{ ns.flag }}", vars()), "99", "Namespace: value set inside if block persists outside")

  ; Test 9: Two namespace objects are independent
  AssertEqual(RendererHelper_RenderNoEscape("{% set ns1 = namespace() %}{% set ns2 = namespace() %}{% set ns1.x = 10 %}{% set ns2.x = 20 %}{{ ns1.x }}-{{ ns2.x }}", vars()), "10-20", "Namespace: two independent namespace objects")

  ; Test 10: Attribute updated multiple times keeps last value
  AssertEqual(RendererHelper_RenderNoEscape("{% set ns = namespace() %}{% set ns.v = 1 %}{% set ns.v = 2 %}{% set ns.v = 3 %}{{ ns.v }}", vars()), "3", "Namespace: attribute updated multiple times keeps last value")

  ClearMap(vars())
EndProcedure
