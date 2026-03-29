; ============================================================================
; PureJinja - TestVariant.pbi
; Unit tests for the JinjaVariant type system
; ============================================================================
EnableExplicit

Procedure RunVariantTests()
  PrintN("--- Variant Tests ---")

  ; Use shorter references
  Protected v.JinjaVariant::JinjaVariant
  Protected v2.JinjaVariant::JinjaVariant
  Protected vCopy.JinjaVariant::JinjaVariant

  ; --- Test Null Variant ---
  JinjaVariant::NullVariant(@v)
  AssertEqual(JinjaVariant::ToString(@v), "", "Null ToString = empty")
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "0", "Null is not truthy")
  AssertEqual(Str(JinjaVariant::ToDouble(@v)), Str(0.0), "Null ToDouble = 0")

  ; --- Test Boolean Variant ---
  JinjaVariant::BoolVariant(@v, #True)
  AssertEqual(JinjaVariant::ToString(@v), "True", "Bool true ToString = True")
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "1", "Bool true is truthy")

  JinjaVariant::BoolVariant(@v, #False)
  AssertEqual(JinjaVariant::ToString(@v), "False", "Bool false ToString = False")
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "0", "Bool false is not truthy")

  ; --- Test Integer Variant ---
  JinjaVariant::IntVariant(@v, 42)
  AssertEqual(JinjaVariant::ToString(@v), "42", "Int 42 ToString = 42")
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "1", "Int 42 is truthy")
  AssertEqual(Str(JinjaVariant::ToDouble(@v)), StrD(42.0), "Int 42 ToDouble = 42.0")

  JinjaVariant::IntVariant(@v, 0)
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "0", "Int 0 is not truthy")

  ; --- Test Double Variant ---
  JinjaVariant::DblVariant(@v, 3.14)
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "1", "Double 3.14 is truthy")

  JinjaVariant::DblVariant(@v, 0.0)
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "0", "Double 0.0 is not truthy")

  ; --- Test String Variant ---
  JinjaVariant::StrVariant(@v, "hello")
  AssertEqual(JinjaVariant::ToString(@v), "hello", "String hello ToString = hello")
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "1", "String hello is truthy")

  JinjaVariant::StrVariant(@v, "")
  AssertEqual(Str(JinjaVariant::IsTruthy(@v)), "0", "Empty string is not truthy")

  ; --- Test Markup Variant ---
  JinjaVariant::MarkupVariant(@v, "<b>bold</b>")
  AssertEqual(JinjaVariant::ToString(@v), "<b>bold</b>", "Markup preserves HTML")
  AssertEqual(Str(v\VType), Str(Jinja::#VT_Markup), "Markup type is #VT_Markup")

  ; --- Test Equality ---
  JinjaVariant::IntVariant(@v, 42)
  JinjaVariant::IntVariant(@v2, 42)
  AssertEqual(Str(JinjaVariant::VariantsEqual(@v, @v2)), "1", "Int 42 == Int 42")

  JinjaVariant::IntVariant(@v2, 43)
  AssertEqual(Str(JinjaVariant::VariantsEqual(@v, @v2)), "0", "Int 42 != Int 43")

  JinjaVariant::StrVariant(@v, "hello")
  JinjaVariant::StrVariant(@v2, "hello")
  AssertEqual(Str(JinjaVariant::VariantsEqual(@v, @v2)), "1", "Str hello == Str hello")

  JinjaVariant::NullVariant(@v)
  JinjaVariant::NullVariant(@v2)
  AssertEqual(Str(JinjaVariant::VariantsEqual(@v, @v2)), "1", "Null == Null")

  ; --- Test Copy ---
  JinjaVariant::StrVariant(@v, "original")
  JinjaVariant::CopyVariant(@vCopy, @v)
  AssertEqual(JinjaVariant::ToString(@vCopy), "original", "Copy preserves value")

  ; --- Test List ---
  Protected listV.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@listV)
  AssertEqual(Str(JinjaVariant::VListSize(@listV)), "0", "New list size = 0")
  AssertEqual(Str(JinjaVariant::IsTruthy(@listV)), "0", "Empty list is not truthy")

  Protected itemV.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@itemV, "first")
  JinjaVariant::VListAdd(@listV, @itemV)
  AssertEqual(Str(JinjaVariant::VListSize(@listV)), "1", "List after add size = 1")
  AssertEqual(Str(JinjaVariant::IsTruthy(@listV)), "1", "Non-empty list is truthy")

  Protected gotV.JinjaVariant::JinjaVariant
  JinjaVariant::VListGet(@listV, 0, @gotV)
  AssertEqual(JinjaVariant::ToString(@gotV), "first", "List get(0) = first")
  JinjaVariant::FreeVariant(@gotV)

  ; Add second item
  JinjaVariant::IntVariant(@itemV, 99)
  JinjaVariant::VListAdd(@listV, @itemV)
  AssertEqual(Str(JinjaVariant::VListSize(@listV)), "2", "List after second add size = 2")

  JinjaVariant::VListGet(@listV, 1, @gotV)
  AssertEqual(JinjaVariant::ToString(@gotV), "99", "List get(1) = 99")
  JinjaVariant::FreeVariant(@gotV)
  JinjaVariant::FreeVariant(@listV)

  ; --- Test Map ---
  Protected mapV.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@mapV)
  AssertEqual(Str(JinjaVariant::VMapSize(@mapV)), "0", "New map size = 0")

  JinjaVariant::StrVariant(@itemV, "World")
  JinjaVariant::VMapSet(@mapV, "name", @itemV)
  AssertEqual(Str(JinjaVariant::VMapSize(@mapV)), "1", "Map after set size = 1")
  AssertEqual(Str(JinjaVariant::VMapHasKey(@mapV, "name")), "1", "Map has key 'name'")
  AssertEqual(Str(JinjaVariant::VMapHasKey(@mapV, "missing")), "0", "Map missing key returns false")

  JinjaVariant::VMapGet(@mapV, "name", @gotV)
  AssertEqual(JinjaVariant::ToString(@gotV), "World", "Map get(name) = World")
  JinjaVariant::FreeVariant(@gotV)
  JinjaVariant::FreeVariant(@mapV)

  ; --- Test Type Names ---
  AssertEqual(JinjaVariant::TypeName(Jinja::#VT_None), "Null", "TypeName Null")
  AssertEqual(JinjaVariant::TypeName(Jinja::#VT_String), "String", "TypeName String")
  AssertEqual(JinjaVariant::TypeName(Jinja::#VT_List), "List", "TypeName List")

  PrintN("")
EndProcedure
