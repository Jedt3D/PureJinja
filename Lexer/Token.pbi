; ============================================================================
; PureJinja - Token.pbi
; Token structure produced by the Lexer
; ============================================================================
EnableExplicit

DeclareModule JinjaToken

  Structure Token
    Type.i            ; TokenType enum from Constants.pbi
    Value.s           ; Token value (text content, operator symbol, etc.)
    LineNumber.i      ; Source line number (1-based)
    ColumnNumber.i    ; Source column number (1-based)
    LStripPrev.i      ; If #True, strip trailing whitespace from the previous TK_Data token
    RStripNext.i      ; If #True, strip leading whitespace from the next TK_Data token
  EndStructure

  ; --- Token name for debugging ---
  Declare.s TokenName(tokenType.i)

EndDeclareModule

Module JinjaToken

  Procedure.s TokenName(tokenType.i)
    Select tokenType
      Case Jinja::#TK_EOF
        ProcedureReturn "EOF"
      Case Jinja::#TK_Data
        ProcedureReturn "DATA"
      Case Jinja::#TK_VariableBegin
        ProcedureReturn "VARIABLE_BEGIN"
      Case Jinja::#TK_VariableEnd
        ProcedureReturn "VARIABLE_END"
      Case Jinja::#TK_BlockBegin
        ProcedureReturn "BLOCK_BEGIN"
      Case Jinja::#TK_BlockEnd
        ProcedureReturn "BLOCK_END"
      Case Jinja::#TK_Name
        ProcedureReturn "NAME"
      Case Jinja::#TK_Keyword
        ProcedureReturn "KEYWORD"
      Case Jinja::#TK_String
        ProcedureReturn "STRING"
      Case Jinja::#TK_Integer
        ProcedureReturn "INTEGER"
      Case Jinja::#TK_Float
        ProcedureReturn "FLOAT"
      Case Jinja::#TK_Operator
        ProcedureReturn "OPERATOR"
      Case Jinja::#TK_Assign
        ProcedureReturn "ASSIGN"
      Case Jinja::#TK_Pipe
        ProcedureReturn "PIPE"
      Case Jinja::#TK_Dot
        ProcedureReturn "DOT"
      Case Jinja::#TK_Comma
        ProcedureReturn "COMMA"
      Case Jinja::#TK_Colon
        ProcedureReturn "COLON"
      Case Jinja::#TK_LParen
        ProcedureReturn "LPAREN"
      Case Jinja::#TK_RParen
        ProcedureReturn "RPAREN"
      Case Jinja::#TK_LBracket
        ProcedureReturn "LBRACKET"
      Case Jinja::#TK_RBracket
        ProcedureReturn "RBRACKET"
      Case Jinja::#TK_LBrace
        ProcedureReturn "LBRACE"
      Case Jinja::#TK_RBrace
        ProcedureReturn "RBRACE"
      Default
        ProcedureReturn "UNKNOWN(" + Str(tokenType) + ")"
    EndSelect
  EndProcedure

EndModule
