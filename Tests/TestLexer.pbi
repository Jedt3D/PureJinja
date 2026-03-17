; ============================================================================
; PureJinja - TestLexer.pbi
; Unit tests for the Lexer / Tokenizer
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Helper: Tokenize a string and return the number of tokens produced
; (including the trailing EOF token)
; ---------------------------------------------------------------------------
Procedure.i LexCountTokens(src.s)
  Protected NewList toks.JinjaToken::Token()
  JinjaLexer::Tokenize(src, toks())
  ProcedureReturn ListSize(toks())
EndProcedure

; ---------------------------------------------------------------------------
; Helper: Return the Type of the Nth token (0-based) in the token list
; ---------------------------------------------------------------------------
Procedure.i LexTokenType(src.s, idx.i)
  Protected NewList toks.JinjaToken::Token()
  JinjaLexer::Tokenize(src, toks())
  Protected n.i = 0
  ForEach toks()
    If n = idx
      ProcedureReturn toks()\Type
    EndIf
    n + 1
  Next
  ProcedureReturn Jinja::#TK_EOF
EndProcedure

; ---------------------------------------------------------------------------
; Helper: Return the Value of the Nth token (0-based)
; ---------------------------------------------------------------------------
Procedure.s LexTokenValue(src.s, idx.i)
  Protected NewList toks.JinjaToken::Token()
  JinjaLexer::Tokenize(src, toks())
  Protected n.i = 0
  ForEach toks()
    If n = idx
      ProcedureReturn toks()\Value
    EndIf
    n + 1
  Next
  ProcedureReturn ""
EndProcedure

; ============================================================================

Procedure RunLexerTests()
  PrintN("--- Lexer Tests ---")

  ; ==========================================================================
  ; 1. Plain text only
  ; ==========================================================================
  ; "Hello World" -> [DATA("Hello World"), EOF]  -> 2 tokens
  AssertEqual(Str(LexCountTokens("Hello World")), "2",
              "Plain text: token count = 2")
  AssertEqual(Str(LexTokenType("Hello World", 0)), Str(Jinja::#TK_Data),
              "Plain text: token[0] type = TK_Data")
  AssertEqual(LexTokenValue("Hello World", 0), "Hello World",
              "Plain text: token[0] value = 'Hello World'")

  ; ==========================================================================
  ; 2. Variable block  {{ name }}
  ; ==========================================================================
  ; Tokens: TK_VariableBegin, TK_Name("name"), TK_VariableEnd, TK_EOF
  Protected src_var.s = "{{ name }}"
  AssertEqual(Str(LexCountTokens(src_var)), "4",
              "Variable block: token count = 4")
  AssertEqual(Str(LexTokenType(src_var, 0)), Str(Jinja::#TK_VariableBegin),
              "Variable block: token[0] = TK_VariableBegin")
  AssertEqual(Str(LexTokenType(src_var, 1)), Str(Jinja::#TK_Name),
              "Variable block: token[1] = TK_Name")
  AssertEqual(LexTokenValue(src_var, 1), "name",
              "Variable block: token[1] value = 'name'")
  AssertEqual(Str(LexTokenType(src_var, 2)), Str(Jinja::#TK_VariableEnd),
              "Variable block: token[2] = TK_VariableEnd")

  ; ==========================================================================
  ; 3. Block tag  {% if x %}
  ; ==========================================================================
  ; Tokens: TK_BlockBegin, TK_Keyword("if"), TK_Name("x"), TK_BlockEnd, TK_EOF
  Protected src_blk.s = "{% if x %}"
  AssertEqual(Str(LexCountTokens(src_blk)), "5",
              "Block tag: token count = 5")
  AssertEqual(Str(LexTokenType(src_blk, 0)), Str(Jinja::#TK_BlockBegin),
              "Block tag: token[0] = TK_BlockBegin")
  AssertEqual(Str(LexTokenType(src_blk, 1)), Str(Jinja::#TK_Keyword),
              "Block tag: token[1] = TK_Keyword")
  AssertEqual(LexTokenValue(src_blk, 1), "if",
              "Block tag: token[1] value = 'if'")
  AssertEqual(Str(LexTokenType(src_blk, 2)), Str(Jinja::#TK_Name),
              "Block tag: token[2] = TK_Name")
  AssertEqual(LexTokenValue(src_blk, 2), "x",
              "Block tag: token[2] value = 'x'")
  AssertEqual(Str(LexTokenType(src_blk, 3)), Str(Jinja::#TK_BlockEnd),
              "Block tag: token[3] = TK_BlockEnd")

  ; ==========================================================================
  ; 4. Comparison operators  == != < > <= >=
  ; ==========================================================================
  Protected NewList opToks.JinjaToken::Token()

  JinjaLexer::Tokenize("{{ a == b }}", opToks())
  FirstElement(opToks()) ; TK_VariableBegin
  NextElement(opToks())  ; TK_Name "a"
  NextElement(opToks())  ; TK_Operator "=="
  AssertEqual(Str(opToks()\Type), Str(Jinja::#TK_Operator),  "Op ==: type = TK_Operator")
  AssertEqual(opToks()\Value, "==",                          "Op ==: value = '=='")

  JinjaLexer::Tokenize("{{ a != b }}", opToks())
  FirstElement(opToks()) : NextElement(opToks()) : NextElement(opToks())
  AssertEqual(opToks()\Value, "!=", "Op !=: value = '!='")

  JinjaLexer::Tokenize("{{ a < b }}", opToks())
  FirstElement(opToks()) : NextElement(opToks()) : NextElement(opToks())
  AssertEqual(opToks()\Value, "<", "Op <: value = '<'")

  JinjaLexer::Tokenize("{{ a > b }}", opToks())
  FirstElement(opToks()) : NextElement(opToks()) : NextElement(opToks())
  AssertEqual(opToks()\Value, ">", "Op >: value = '>'")

  JinjaLexer::Tokenize("{{ a <= b }}", opToks())
  FirstElement(opToks()) : NextElement(opToks()) : NextElement(opToks())
  AssertEqual(opToks()\Value, "<=", "Op <=: value = '<='")

  JinjaLexer::Tokenize("{{ a >= b }}", opToks())
  FirstElement(opToks()) : NextElement(opToks()) : NextElement(opToks())
  AssertEqual(opToks()\Value, ">=", "Op >=: value = '>='")

  ; ==========================================================================
  ; 5. String literals with escape sequences
  ; ==========================================================================
  ; {{ "hello" }}  -> VariableBegin, String("hello"), VariableEnd, EOF
  Protected src_str.s = "{{ " + Chr(34) + "hello" + Chr(34) + " }}"
  AssertEqual(Str(LexTokenType(src_str, 1)), Str(Jinja::#TK_String),
              "String literal: token[1] type = TK_String")
  AssertEqual(LexTokenValue(src_str, 1), "hello",
              "String literal: token[1] value = 'hello'")

  ; String with \n escape: "a\nb"  -> value should contain newline character
  Protected src_esc.s = "{{ " + Chr(34) + "a\nb" + Chr(34) + " }}"
  AssertTrue(Bool(FindString(LexTokenValue(src_esc, 1), Chr(10)) > 0),
             "String escape \\n: value contains newline")

  ; Single-quoted string
  Protected src_sq.s = "{{ 'world' }}"
  AssertEqual(LexTokenValue(src_sq, 1), "world",
              "Single-quoted string: value = 'world'")

  ; ==========================================================================
  ; 6. Number literals (integer and float)
  ; ==========================================================================
  Protected src_int.s = "{{ 42 }}"
  AssertEqual(Str(LexTokenType(src_int, 1)), Str(Jinja::#TK_Integer),
              "Integer literal: type = TK_Integer")
  AssertEqual(LexTokenValue(src_int, 1), "42",
              "Integer literal: value = '42'")

  Protected src_flt.s = "{{ 3.14 }}"
  AssertEqual(Str(LexTokenType(src_flt, 1)), Str(Jinja::#TK_Float),
              "Float literal: type = TK_Float")
  AssertEqual(LexTokenValue(src_flt, 1), "3.14",
              "Float literal: value = '3.14'")

  ; ==========================================================================
  ; 7. Comments are skipped entirely
  ; ==========================================================================
  ; "{# comment #}" -> just [EOF]  (no Data token before or after)
  AssertEqual(Str(LexCountTokens("{# this is a comment #}")), "1",
              "Comment only: token count = 1 (just EOF)")
  AssertEqual(Str(LexTokenType("{# this is a comment #}", 0)), Str(Jinja::#TK_EOF),
              "Comment only: token[0] = TK_EOF")

  ; Text before and after comment: no comment tokens in output
  Protected src_cmt2.s = "before{# comment #}after"
  AssertEqual(Str(LexCountTokens(src_cmt2)), "3",
              "Comment surrounded by text: token count = 3")
  AssertEqual(LexTokenValue(src_cmt2, 0), "before",
              "Comment surrounded: token[0] = 'before'")
  AssertEqual(LexTokenValue(src_cmt2, 1), "after",
              "Comment surrounded: token[1] = 'after'")

  ; ==========================================================================
  ; 8. Filter pipe:  {{ name|upper }}
  ; ==========================================================================
  ; Tokens: VarBegin, Name("name"), Pipe, Name("upper"), VarEnd, EOF
  Protected src_filter.s = "{{ name|upper }}"
  AssertEqual(Str(LexTokenType(src_filter, 1)), Str(Jinja::#TK_Name),
              "Filter: token[1] = TK_Name (name)")
  AssertEqual(Str(LexTokenType(src_filter, 2)), Str(Jinja::#TK_Pipe),
              "Filter: token[2] = TK_Pipe")
  AssertEqual(Str(LexTokenType(src_filter, 3)), Str(Jinja::#TK_Name),
              "Filter: token[3] = TK_Name (upper)")
  AssertEqual(LexTokenValue(src_filter, 3), "upper",
              "Filter: token[3] value = 'upper'")

  ; ==========================================================================
  ; 9. Mixed template: text + variable + block
  ; ==========================================================================
  ; "Hello {{ name }}!"
  ; Tokens: Data("Hello "), VarBegin, Name("name"), VarEnd, Data("!"), EOF
  Protected src_mix.s = "Hello {{ name }}!"
  AssertEqual(Str(LexCountTokens(src_mix)), "6",
              "Mixed template: token count = 6")
  AssertEqual(Str(LexTokenType(src_mix, 0)), Str(Jinja::#TK_Data),
              "Mixed: token[0] = TK_Data")
  AssertEqual(LexTokenValue(src_mix, 0), "Hello ",
              "Mixed: token[0] value = 'Hello '")
  AssertEqual(Str(LexTokenType(src_mix, 1)), Str(Jinja::#TK_VariableBegin),
              "Mixed: token[1] = TK_VariableBegin")
  AssertEqual(Str(LexTokenType(src_mix, 4)), Str(Jinja::#TK_Data),
              "Mixed: token[4] = TK_Data")
  AssertEqual(LexTokenValue(src_mix, 4), "!",
              "Mixed: token[4] value = '!'")

  ; ==========================================================================
  ; 10. Keyword recognition
  ; ==========================================================================
  ; 'for', 'endfor', 'in', 'and', 'or', 'not', 'true', 'false', 'none'
  ; should all produce TK_Keyword, not TK_Name
  AssertEqual(Str(LexTokenType("{% for %}", 1)), Str(Jinja::#TK_Keyword),
              "Keyword 'for': type = TK_Keyword")
  AssertEqual(Str(LexTokenType("{% endfor %}", 1)), Str(Jinja::#TK_Keyword),
              "Keyword 'endfor': type = TK_Keyword")
  AssertEqual(Str(LexTokenType("{{ true }}", 1)), Str(Jinja::#TK_Keyword),
              "Keyword 'true': type = TK_Keyword")
  AssertEqual(Str(LexTokenType("{{ false }}", 1)), Str(Jinja::#TK_Keyword),
              "Keyword 'false': type = TK_Keyword")
  AssertEqual(Str(LexTokenType("{{ none }}", 1)), Str(Jinja::#TK_Keyword),
              "Keyword 'none': type = TK_Keyword")

  ; A plain identifier must NOT be a keyword
  AssertEqual(Str(LexTokenType("{{ myVar }}", 1)), Str(Jinja::#TK_Name),
              "Identifier 'myVar': type = TK_Name")

  ; ==========================================================================
  ; 11. Assignment operator vs equality operator
  ; ==========================================================================
  ; Inside {% set x = 5 %} the '=' must be TK_Assign
  Protected src_assign.s = "{% set x = 5 %}"
  ; tokens: BlockBegin, Keyword(set), Name(x), Assign(=), Integer(5), BlockEnd, EOF
  AssertEqual(Str(LexTokenType(src_assign, 3)), Str(Jinja::#TK_Assign),
              "Assignment =: token[3] type = TK_Assign")
  AssertEqual(LexTokenValue(src_assign, 3), "=",
              "Assignment =: value = '='")

  PrintN("")
EndProcedure
