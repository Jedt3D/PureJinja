; ============================================================================
; PureJinja - TestParser.pbi
; Unit tests for the Parser (token stream -> AST)
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Helper: Lex + Parse a template string.
; Returns pointer to the root TemplateNode.
; ---------------------------------------------------------------------------
Procedure.i ParseTemplate(src.s)
  Protected NewList toks.JinjaToken::Token()
  JinjaError::ClearError()
  JinjaLexer::Tokenize(src, toks())
  ProcedureReturn JinjaParser::Parse(toks())
EndProcedure

; ============================================================================

Procedure RunParserTests()
  PrintN("--- Parser Tests ---")

  Protected *root.JinjaAST::ASTNode
  Protected *child.JinjaAST::ASTNode
  Protected *expr.JinjaAST::ASTNode

  ; ==========================================================================
  ; 1. Simple variable:  {{ name }}
  ;    Expected tree:  Template -> Output -> Variable("name")
  ; ==========================================================================
  *root = ParseTemplate("{{ name }}")
  AssertTrue(Bool(*root <> #Null),          "Var parse: root is not null")
  AssertEqual(Str(*root\NodeType), Str(Jinja::#NODE_Template),
              "Var parse: root type = NODE_Template")
  AssertFalse(JinjaError::HasError(),       "Var parse: no error")

  *child = *root\Body
  AssertTrue(Bool(*child <> #Null),         "Var parse: root has a child")
  AssertEqual(Str(*child\NodeType), Str(Jinja::#NODE_Output),
              "Var parse: child type = NODE_Output")

  *expr = *child\Left
  AssertTrue(Bool(*expr <> #Null),          "Var parse: output has expression")
  AssertEqual(Str(*expr\NodeType), Str(Jinja::#NODE_Variable),
              "Var parse: expression type = NODE_Variable")
  AssertEqual(*expr\StringVal, "name",      "Var parse: variable name = 'name'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 2. Integer literal:  {{ 42 }}
  ;    Expected:  Template -> Output -> Literal(Integer, 42)
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{{ 42 }}")
  *child = *root\Body
  AssertTrue(Bool(*child <> #Null),         "Int literal: output node present")
  *expr = *child\Left
  AssertEqual(Str(*expr\NodeType), Str(Jinja::#NODE_Literal),
              "Int literal: expression = NODE_Literal")
  AssertEqual(Str(*expr\IntVal), Str(Jinja::#LIT_Integer),
              "Int literal: subtype = LIT_Integer")
  AssertEqual(*expr\StringVal, "42",        "Int literal: StringVal = '42'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 3. String literal:  {{ "hello" }}
  ;    Expected:  Template -> Output -> Literal(String, "hello")
  ; ==========================================================================
  JinjaError::ClearError()
  Protected src_strlit.s = "{{ " + Chr(34) + "hello" + Chr(34) + " }}"
  *root = ParseTemplate(src_strlit)
  *child = *root\Body
  *expr = *child\Left
  AssertEqual(Str(*expr\NodeType), Str(Jinja::#NODE_Literal),
              "Str literal: expression = NODE_Literal")
  AssertEqual(Str(*expr\IntVal), Str(Jinja::#LIT_String),
              "Str literal: subtype = LIT_String")
  AssertEqual(*expr\StringVal, "hello",     "Str literal: value = 'hello'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 4. Filter:  {{ name|upper }}
  ;    Expected:  Template -> Output -> Filter("upper") -> Variable("name")
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{{ name|upper }}")
  *child = *root\Body
  *expr = *child\Left
  AssertEqual(Str(*expr\NodeType), Str(Jinja::#NODE_Filter),
              "Filter: expression = NODE_Filter")
  AssertEqual(*expr\StringVal, "upper",     "Filter: filter name = 'upper'")

  Protected *filterInput.JinjaAST::ASTNode = *expr\Left
  AssertTrue(Bool(*filterInput <> #Null),   "Filter: input expression present")
  AssertEqual(Str(*filterInput\NodeType), Str(Jinja::#NODE_Variable),
              "Filter: input type = NODE_Variable")
  AssertEqual(*filterInput\StringVal, "name",
              "Filter: input variable = 'name'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 5. If statement:  {% if x %}yes{% endif %}
  ;    Expected:  Template -> If(condition=Variable("x")) -> Text("yes")
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{% if x %}yes{% endif %}")
  AssertFalse(JinjaError::HasError(),       "If stmt: no parse error")

  *child = *root\Body
  AssertTrue(Bool(*child <> #Null),         "If stmt: root has child")
  AssertEqual(Str(*child\NodeType), Str(Jinja::#NODE_If),
              "If stmt: child type = NODE_If")

  Protected *ifCond.JinjaAST::ASTNode = *child\Left
  AssertTrue(Bool(*ifCond <> #Null),        "If stmt: condition present")
  AssertEqual(Str(*ifCond\NodeType), Str(Jinja::#NODE_Variable),
              "If stmt: condition type = NODE_Variable")
  AssertEqual(*ifCond\StringVal, "x",       "If stmt: condition name = 'x'")

  Protected *ifBody.JinjaAST::ASTNode = *child\Body
  AssertTrue(Bool(*ifBody <> #Null),        "If stmt: body is not empty")
  AssertEqual(Str(*ifBody\NodeType), Str(Jinja::#NODE_Text),
              "If stmt: body[0] type = NODE_Text")
  AssertEqual(*ifBody\StringVal, "yes",     "If stmt: body[0] value = 'yes'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 6. For loop:  {% for i in items %}{{ i }}{% endfor %}
  ;    Expected:  Template -> For(var="i", iterable=Variable("items"))
  ;               For\Body -> Output -> Variable("i")
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{% for i in items %}{{ i }}{% endfor %}")
  AssertFalse(JinjaError::HasError(),       "For loop: no parse error")

  *child = *root\Body
  AssertTrue(Bool(*child <> #Null),         "For loop: root has child")
  AssertEqual(Str(*child\NodeType), Str(Jinja::#NODE_For),
              "For loop: child type = NODE_For")
  AssertEqual(*child\StringVal, "i",        "For loop: loop var = 'i'")

  Protected *iterable.JinjaAST::ASTNode = *child\Left
  AssertTrue(Bool(*iterable <> #Null),      "For loop: iterable present")
  AssertEqual(Str(*iterable\NodeType), Str(Jinja::#NODE_Variable),
              "For loop: iterable type = NODE_Variable")
  AssertEqual(*iterable\StringVal, "items", "For loop: iterable name = 'items'")

  Protected *forBody.JinjaAST::ASTNode = *child\Body
  AssertTrue(Bool(*forBody <> #Null),       "For loop: body not empty")
  AssertEqual(Str(*forBody\NodeType), Str(Jinja::#NODE_Output),
              "For loop: body[0] type = NODE_Output")
  Protected *forBodyExpr.JinjaAST::ASTNode = *forBody\Left
  AssertEqual(Str(*forBodyExpr\NodeType), Str(Jinja::#NODE_Variable),
              "For loop: body[0] expr = NODE_Variable")
  AssertEqual(*forBodyExpr\StringVal, "i",  "For loop: body[0] var name = 'i'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 7. Binary expression:  {{ a + b }}
  ;    Expected:  Template -> Output -> BinaryOp("+") -> Variable("a"), Variable("b")
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{{ a + b }}")
  AssertFalse(JinjaError::HasError(),       "BinaryOp: no parse error")

  *child = *root\Body
  *expr = *child\Left
  AssertEqual(Str(*expr\NodeType), Str(Jinja::#NODE_BinaryOp),
              "BinaryOp: expression = NODE_BinaryOp")
  AssertEqual(*expr\StringVal, "+",         "BinaryOp: operator = '+'")

  Protected *binLeft.JinjaAST::ASTNode = *expr\Left
  Protected *binRight.JinjaAST::ASTNode = *expr\Right
  AssertEqual(Str(*binLeft\NodeType), Str(Jinja::#NODE_Variable),
              "BinaryOp: left = NODE_Variable")
  AssertEqual(*binLeft\StringVal, "a",      "BinaryOp: left name = 'a'")
  AssertEqual(Str(*binRight\NodeType), Str(Jinja::#NODE_Variable),
              "BinaryOp: right = NODE_Variable")
  AssertEqual(*binRight\StringVal, "b",     "BinaryOp: right name = 'b'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 8. Set statement:  {% set x = 5 %}
  ;    Expected:  Template -> Set(var="x") -> Literal(Integer, 5)
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{% set x = 5 %}")
  AssertFalse(JinjaError::HasError(),       "Set stmt: no parse error")

  *child = *root\Body
  AssertTrue(Bool(*child <> #Null),         "Set stmt: root has child")
  AssertEqual(Str(*child\NodeType), Str(Jinja::#NODE_Set),
              "Set stmt: child type = NODE_Set")
  AssertEqual(*child\StringVal, "x",        "Set stmt: variable name = 'x'")

  Protected *setValue.JinjaAST::ASTNode = *child\Left
  AssertTrue(Bool(*setValue <> #Null),      "Set stmt: value expression present")
  AssertEqual(Str(*setValue\NodeType), Str(Jinja::#NODE_Literal),
              "Set stmt: value type = NODE_Literal")
  AssertEqual(Str(*setValue\IntVal), Str(Jinja::#LIT_Integer),
              "Set stmt: value subtype = LIT_Integer")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 9. Comparison expression:  {{ a == b }}
  ;    Expected:  Template -> Output -> Compare("==") -> Variable("a"), Variable("b")
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{{ a == b }}")
  AssertFalse(JinjaError::HasError(),       "Compare ==: no parse error")
  *child = *root\Body
  *expr = *child\Left
  AssertEqual(Str(*expr\NodeType), Str(Jinja::#NODE_Compare),
              "Compare ==: expression = NODE_Compare")
  AssertEqual(*expr\StringVal, "==",        "Compare ==: operator = '=='")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 10. Plain text node:  "Hello"
  ;     Expected:  Template -> Text("Hello")
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("Hello")
  AssertFalse(JinjaError::HasError(),       "Text node: no parse error")
  *child = *root\Body
  AssertTrue(Bool(*child <> #Null),         "Text node: root has child")
  AssertEqual(Str(*child\NodeType), Str(Jinja::#NODE_Text),
              "Text node: type = NODE_Text")
  AssertEqual(*child\StringVal, "Hello",    "Text node: value = 'Hello'")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 11. Float literal:  {{ 2.5 }}
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("{{ 2.5 }}")
  *child = *root\Body
  *expr = *child\Left
  AssertEqual(Str(*expr\NodeType), Str(Jinja::#NODE_Literal),
              "Float literal: expression = NODE_Literal")
  AssertEqual(Str(*expr\IntVal), Str(Jinja::#LIT_Float),
              "Float literal: subtype = LIT_Float")
  JinjaAST::FreeAST(*root)

  ; ==========================================================================
  ; 12. Empty template produces root with no children
  ; ==========================================================================
  JinjaError::ClearError()
  *root = ParseTemplate("")
  AssertFalse(JinjaError::HasError(),       "Empty template: no parse error")
  AssertTrue(Bool(*root <> #Null),          "Empty template: root not null")
  AssertEqual(Str(*root\NodeType), Str(Jinja::#NODE_Template),
              "Empty template: root = NODE_Template")
  AssertTrue(Bool(*root\Body = #Null),      "Empty template: body is null")
  JinjaAST::FreeAST(*root)

  PrintN("")
EndProcedure
