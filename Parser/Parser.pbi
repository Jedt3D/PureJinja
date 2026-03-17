; ============================================================================
; PureJinja - Parser.pbi
; Recursive descent parser: token stream -> AST
; Expression precedence: or -> and -> not -> comparison -> additive ->
;   multiplicative -> unary -> postfix (dot, bracket, pipe, call) -> primary
; ============================================================================
EnableExplicit

DeclareModule JinjaParser

  ; Parse a token list into an AST tree. Returns pointer to root TemplateNode.
  Declare.i Parse(List tokens.JinjaToken::Token())

EndDeclareModule

Module JinjaParser

  ; --- Parser state (module-level for simplicity) ---
  ; We copy tokens into an array for random access
  Global Dim gTokens.JinjaToken::Token(0)
  Global gTokenCount.i = 0
  Global gPos.i = 0

  ; --- Forward declarations ---
  Declare.i ParseExpression()
  Declare.i ParseBlockStatement()

  ; --- Token access ---
  Procedure.i CurrentType()
    If gPos < gTokenCount
      ProcedureReturn gTokens(gPos)\Type
    EndIf
    ProcedureReturn Jinja::#TK_EOF
  EndProcedure

  Procedure.s CurrentValue()
    If gPos < gTokenCount
      ProcedureReturn gTokens(gPos)\Value
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.i CurrentLine()
    If gPos < gTokenCount
      ProcedureReturn gTokens(gPos)\LineNumber
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure Advance()
    If gPos < gTokenCount - 1
      gPos + 1
    EndIf
  EndProcedure

  Procedure.i IsAtEnd()
    ProcedureReturn Bool(CurrentType() = Jinja::#TK_EOF)
  EndProcedure

  Procedure.i Expect(expectedType.i)
    ; Expect current token to be of given type. Returns #True if matched.
    If CurrentType() <> expectedType
      JinjaError::SetError(Jinja::#ERR_Syntax, "Expected " + JinjaToken::TokenName(expectedType) + " but got " + JinjaToken::TokenName(CurrentType()) + " ('" + CurrentValue() + "')", CurrentLine())
      ProcedureReturn #False
    EndIf
    Advance()
    ProcedureReturn #True
  EndProcedure

  Procedure.i ExpectKeyword(keyword.s)
    If CurrentType() <> Jinja::#TK_Keyword Or LCase(CurrentValue()) <> LCase(keyword)
      JinjaError::SetError(Jinja::#ERR_Syntax, "Expected keyword '" + keyword + "' but got '" + CurrentValue() + "'", CurrentLine())
      ProcedureReturn #False
    EndIf
    Advance()
    ProcedureReturn #True
  EndProcedure

  ; --- Look-ahead helpers ---
  Procedure.s PeekBlockKeyword()
    ; If current token is BLOCK_BEGIN, return the next keyword
    If CurrentType() = Jinja::#TK_BlockBegin
      If gPos + 1 < gTokenCount
        If gTokens(gPos + 1)\Type = Jinja::#TK_Keyword
          ProcedureReturn LCase(gTokens(gPos + 1)\Value)
        EndIf
      EndIf
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.i IsBlockKeyword(keyword.s)
    If CurrentType() = Jinja::#TK_BlockBegin
      If gPos + 1 < gTokenCount
        If gTokens(gPos + 1)\Type = Jinja::#TK_Keyword And LCase(gTokens(gPos + 1)\Value) = LCase(keyword)
          ProcedureReturn #True
        EndIf
      EndIf
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure SkipToBlockEnd()
    While CurrentType() <> Jinja::#TK_BlockEnd And Not IsAtEnd()
      Advance()
    Wend
    If CurrentType() = Jinja::#TK_BlockEnd
      Advance()
    EndIf
  EndProcedure

  ; ===== Statement Body Parsing Helpers =====
  ; These parse a list of nodes (text, output, nested blocks) until a terminator

  Macro ParseBodyUntilKeyword(parentNode, addProc, kw1, kw2, kw3)
    While Not IsAtEnd() And Not IsBlockKeyword(kw1) And Not IsBlockKeyword(kw2) And Not IsBlockKeyword(kw3)
      If CurrentType() = Jinja::#TK_Data
        addProc(parentNode, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
        Advance()
      ElseIf CurrentType() = Jinja::#TK_VariableBegin
        Expect(Jinja::#TK_VariableBegin)
        If JinjaError::HasError() : Break : EndIf
        Protected *_expr_.JinjaAST::ASTNode = ParseExpression()
        If JinjaError::HasError() : Break : EndIf
        Expect(Jinja::#TK_VariableEnd)
        If JinjaError::HasError() : Break : EndIf
        addProc(parentNode, JinjaAST::NewOutputNode(*_expr_, CurrentLine()))
      ElseIf CurrentType() = Jinja::#TK_BlockBegin
        Protected _pbk_.s = PeekBlockKeyword()
        If _pbk_ = kw1 Or _pbk_ = kw2 Or _pbk_ = kw3
          Break
        EndIf
        Protected *_nested_.JinjaAST::ASTNode = ParseBlockStatement()
        If *_nested_
          addProc(parentNode, *_nested_)
        EndIf
        If JinjaError::HasError() : Break : EndIf
      Else
        Advance()
      EndIf
    Wend
  EndMacro

  ; ===== Statement Parsing =====

  Procedure.i ParseTextNode()
    Protected *node.JinjaAST::ASTNode = JinjaAST::NewTextNode(CurrentValue(), CurrentLine())
    Advance()
    ProcedureReturn *node
  EndProcedure

  Procedure.i ParseOutputNode()
    Expect(Jinja::#TK_VariableBegin)
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Protected *expr.JinjaAST::ASTNode = ParseExpression()
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Expect(Jinja::#TK_VariableEnd)
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    ProcedureReturn JinjaAST::NewOutputNode(*expr, CurrentLine())
  EndProcedure

  Procedure.i ParseIfStatement()
    Protected lineNum.i = CurrentLine()
    Advance() ; Skip 'if' keyword

    Protected *condition.JinjaAST::ASTNode = ParseExpression()
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf
    Expect(Jinja::#TK_BlockEnd)
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Protected *ifNode.JinjaAST::ASTNode = JinjaAST::NewIfNode(*condition, lineNum)

    ; Parse if body
    While Not IsAtEnd() And Not IsBlockKeyword("elif") And Not IsBlockKeyword("else") And Not IsBlockKeyword("endif")
      If CurrentType() = Jinja::#TK_Data
        JinjaAST::AddChild(*ifNode, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
        Advance()
      ElseIf CurrentType() = Jinja::#TK_VariableBegin
        Protected *outN.JinjaAST::ASTNode = ParseOutputNode()
        If *outN : JinjaAST::AddChild(*ifNode, *outN) : EndIf
        If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf
      ElseIf CurrentType() = Jinja::#TK_BlockBegin
        Protected pk.s = PeekBlockKeyword()
        If pk = "elif" Or pk = "else" Or pk = "endif"
          Break
        EndIf
        Protected *nested.JinjaAST::ASTNode = ParseBlockStatement()
        If *nested : JinjaAST::AddChild(*ifNode, *nested) : EndIf
        If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf
      Else
        Advance()
      EndIf
    Wend

    ; Parse elif clauses
    While IsBlockKeyword("elif")
      Expect(Jinja::#TK_BlockBegin)
      Advance() ; skip 'elif'
      Protected *elifCond.JinjaAST::ASTNode = ParseExpression()
      If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf
      Expect(Jinja::#TK_BlockEnd)
      If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf

      Protected *clause.JinjaAST::ElseIfClause = JinjaAST::AddElseIf(*ifNode, *elifCond)

      ; Parse elif body
      While Not IsAtEnd() And Not IsBlockKeyword("elif") And Not IsBlockKeyword("else") And Not IsBlockKeyword("endif")
        If CurrentType() = Jinja::#TK_Data
          JinjaAST::AddElseIfBody(*clause, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
          Advance()
        ElseIf CurrentType() = Jinja::#TK_VariableBegin
          Protected *eiOut.JinjaAST::ASTNode = ParseOutputNode()
          If *eiOut : JinjaAST::AddElseIfBody(*clause, *eiOut) : EndIf
          If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf
        ElseIf CurrentType() = Jinja::#TK_BlockBegin
          Protected eipk.s = PeekBlockKeyword()
          If eipk = "elif" Or eipk = "else" Or eipk = "endif"
            Break
          EndIf
          Protected *eiNested.JinjaAST::ASTNode = ParseBlockStatement()
          If *eiNested : JinjaAST::AddElseIfBody(*clause, *eiNested) : EndIf
          If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf
        Else
          Advance()
        EndIf
      Wend
    Wend

    ; Parse else clause
    If IsBlockKeyword("else")
      Expect(Jinja::#TK_BlockBegin)
      Advance() ; skip 'else'
      Expect(Jinja::#TK_BlockEnd)
      If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf

      While Not IsAtEnd() And Not IsBlockKeyword("endif")
        If CurrentType() = Jinja::#TK_Data
          JinjaAST::AddElseChild(*ifNode, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
          Advance()
        ElseIf CurrentType() = Jinja::#TK_VariableBegin
          Protected *elseOut.JinjaAST::ASTNode = ParseOutputNode()
          If *elseOut : JinjaAST::AddElseChild(*ifNode, *elseOut) : EndIf
          If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf
        ElseIf CurrentType() = Jinja::#TK_BlockBegin
          If PeekBlockKeyword() = "endif"
            Break
          EndIf
          Protected *elseNested.JinjaAST::ASTNode = ParseBlockStatement()
          If *elseNested : JinjaAST::AddElseChild(*ifNode, *elseNested) : EndIf
          If JinjaError::HasError() : ProcedureReturn *ifNode : EndIf
        Else
          Advance()
        EndIf
      Wend
    EndIf

    ; Expect {% endif %}
    Expect(Jinja::#TK_BlockBegin)
    ExpectKeyword("endif")
    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn *ifNode
  EndProcedure

  Procedure.i ParseForStatement()
    Protected lineNum.i = CurrentLine()
    Advance() ; Skip 'for' keyword

    ; Get variable name
    If CurrentType() <> Jinja::#TK_Name
      JinjaError::SetError(Jinja::#ERR_Syntax, "Expected variable name in for statement", CurrentLine())
      ProcedureReturn #Null
    EndIf
    Protected varName.s = CurrentValue()
    Advance()

    ExpectKeyword("in")
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Protected *iterable.JinjaAST::ASTNode = ParseExpression()
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Expect(Jinja::#TK_BlockEnd)
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Protected *forNode.JinjaAST::ASTNode = JinjaAST::NewForNode(varName, *iterable, lineNum)

    ; Parse body
    While Not IsAtEnd() And Not IsBlockKeyword("else") And Not IsBlockKeyword("endfor")
      If CurrentType() = Jinja::#TK_Data
        JinjaAST::AddChild(*forNode, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
        Advance()
      ElseIf CurrentType() = Jinja::#TK_VariableBegin
        Protected *fOut.JinjaAST::ASTNode = ParseOutputNode()
        If *fOut : JinjaAST::AddChild(*forNode, *fOut) : EndIf
        If JinjaError::HasError() : ProcedureReturn *forNode : EndIf
      ElseIf CurrentType() = Jinja::#TK_BlockBegin
        Protected fpk.s = PeekBlockKeyword()
        If fpk = "else" Or fpk = "endfor"
          Break
        EndIf
        Protected *fNested.JinjaAST::ASTNode = ParseBlockStatement()
        If *fNested : JinjaAST::AddChild(*forNode, *fNested) : EndIf
        If JinjaError::HasError() : ProcedureReturn *forNode : EndIf
      Else
        Advance()
      EndIf
    Wend

    ; Optional else clause
    If IsBlockKeyword("else")
      Expect(Jinja::#TK_BlockBegin)
      Advance() ; skip 'else'
      Expect(Jinja::#TK_BlockEnd)
      If JinjaError::HasError() : ProcedureReturn *forNode : EndIf

      While Not IsAtEnd() And Not IsBlockKeyword("endfor")
        If CurrentType() = Jinja::#TK_Data
          JinjaAST::AddElseChild(*forNode, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
          Advance()
        ElseIf CurrentType() = Jinja::#TK_VariableBegin
          Protected *feOut.JinjaAST::ASTNode = ParseOutputNode()
          If *feOut : JinjaAST::AddElseChild(*forNode, *feOut) : EndIf
          If JinjaError::HasError() : ProcedureReturn *forNode : EndIf
        ElseIf CurrentType() = Jinja::#TK_BlockBegin
          If PeekBlockKeyword() = "endfor"
            Break
          EndIf
          Protected *feNested.JinjaAST::ASTNode = ParseBlockStatement()
          If *feNested : JinjaAST::AddElseChild(*forNode, *feNested) : EndIf
          If JinjaError::HasError() : ProcedureReturn *forNode : EndIf
        Else
          Advance()
        EndIf
      Wend
    EndIf

    ; Expect {% endfor %}
    Expect(Jinja::#TK_BlockBegin)
    ExpectKeyword("endfor")
    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn *forNode
  EndProcedure

  Procedure.i ParseSetStatement()
    Advance() ; skip 'set'

    If CurrentType() <> Jinja::#TK_Name
      JinjaError::SetError(Jinja::#ERR_Syntax, "Expected variable name in set statement", CurrentLine())
      ProcedureReturn #Null
    EndIf
    Protected varName.s = CurrentValue()
    Advance()

    Expect(Jinja::#TK_Assign)
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Protected *value.JinjaAST::ASTNode = ParseExpression()
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn JinjaAST::NewSetNode(varName, *value, CurrentLine())
  EndProcedure

  Procedure.i ParseBlockDefinition()
    Advance() ; skip 'block'

    If CurrentType() <> Jinja::#TK_Name
      JinjaError::SetError(Jinja::#ERR_Syntax, "Expected block name", CurrentLine())
      ProcedureReturn #Null
    EndIf
    Protected blockName.s = CurrentValue()
    Advance()

    Expect(Jinja::#TK_BlockEnd)
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    Protected *blockNode.JinjaAST::ASTNode = JinjaAST::NewBlockNode(blockName, CurrentLine())

    ; Parse body
    While Not IsAtEnd() And Not IsBlockKeyword("endblock")
      If CurrentType() = Jinja::#TK_Data
        JinjaAST::AddChild(*blockNode, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
        Advance()
      ElseIf CurrentType() = Jinja::#TK_VariableBegin
        Protected *bOut.JinjaAST::ASTNode = ParseOutputNode()
        If *bOut : JinjaAST::AddChild(*blockNode, *bOut) : EndIf
        If JinjaError::HasError() : ProcedureReturn *blockNode : EndIf
      ElseIf CurrentType() = Jinja::#TK_BlockBegin
        If PeekBlockKeyword() = "endblock"
          Break
        EndIf
        Protected *bNested.JinjaAST::ASTNode = ParseBlockStatement()
        If *bNested : JinjaAST::AddChild(*blockNode, *bNested) : EndIf
        If JinjaError::HasError() : ProcedureReturn *blockNode : EndIf
      Else
        Advance()
      EndIf
    Wend

    ; Expect {% endblock %} (optional block name after endblock)
    Expect(Jinja::#TK_BlockBegin)
    ExpectKeyword("endblock")
    If CurrentType() = Jinja::#TK_Name
      Advance() ; skip optional block name
    EndIf
    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn *blockNode
  EndProcedure

  Procedure.i ParseExtendsStatement()
    Advance() ; skip 'extends'

    If CurrentType() <> Jinja::#TK_String
      JinjaError::SetError(Jinja::#ERR_Syntax, "extends requires a string template name", CurrentLine())
      ProcedureReturn #Null
    EndIf
    Protected templateName.s = CurrentValue()
    Advance()

    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn JinjaAST::NewExtendsNode(templateName, CurrentLine())
  EndProcedure

  Procedure.i ParseIncludeStatement()
    Advance() ; skip 'include'

    If CurrentType() <> Jinja::#TK_String
      JinjaError::SetError(Jinja::#ERR_Syntax, "include requires a string template name", CurrentLine())
      ProcedureReturn #Null
    EndIf
    Protected templateName.s = CurrentValue()
    Advance()

    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn JinjaAST::NewIncludeNode(templateName, CurrentLine())
  EndProcedure

  Procedure.i ParseMacroStatement()
    Advance() ; skip 'macro'

    If CurrentType() <> Jinja::#TK_Name
      JinjaError::SetError(Jinja::#ERR_Syntax, "Expected macro name", CurrentLine())
      ProcedureReturn #Null
    EndIf
    Protected macroName.s = CurrentValue()
    Advance()

    Protected *macroNode.JinjaAST::ASTNode = JinjaAST::NewMacroNode(macroName, CurrentLine())

    ; Parse parameters
    If CurrentType() = Jinja::#TK_LParen
      Advance()
      While CurrentType() <> Jinja::#TK_RParen And Not IsAtEnd()
        If CurrentType() = Jinja::#TK_Name
          JinjaAST::AddMacroParam(*macroNode, CurrentValue())
          Advance()
        EndIf
        If CurrentType() = Jinja::#TK_Comma
          Advance()
        EndIf
      Wend
      Expect(Jinja::#TK_RParen)
      If JinjaError::HasError() : ProcedureReturn *macroNode : EndIf
    EndIf

    Expect(Jinja::#TK_BlockEnd)
    If JinjaError::HasError() : ProcedureReturn *macroNode : EndIf

    ; Parse body
    While Not IsAtEnd() And Not IsBlockKeyword("endmacro")
      If CurrentType() = Jinja::#TK_Data
        JinjaAST::AddChild(*macroNode, JinjaAST::NewTextNode(CurrentValue(), CurrentLine()))
        Advance()
      ElseIf CurrentType() = Jinja::#TK_VariableBegin
        Protected *mOut.JinjaAST::ASTNode = ParseOutputNode()
        If *mOut : JinjaAST::AddChild(*macroNode, *mOut) : EndIf
        If JinjaError::HasError() : ProcedureReturn *macroNode : EndIf
      ElseIf CurrentType() = Jinja::#TK_BlockBegin
        If PeekBlockKeyword() = "endmacro"
          Break
        EndIf
        Protected *mNested.JinjaAST::ASTNode = ParseBlockStatement()
        If *mNested : JinjaAST::AddChild(*macroNode, *mNested) : EndIf
        If JinjaError::HasError() : ProcedureReturn *macroNode : EndIf
      Else
        Advance()
      EndIf
    Wend

    Expect(Jinja::#TK_BlockBegin)
    ExpectKeyword("endmacro")
    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn *macroNode
  EndProcedure

  Procedure.i ParseCallStatement()
    Advance() ; skip 'call'

    If CurrentType() <> Jinja::#TK_Name
      JinjaError::SetError(Jinja::#ERR_Syntax, "Expected function name in call statement", CurrentLine())
      ProcedureReturn #Null
    EndIf
    Protected funcName.s = CurrentValue()
    Advance()

    Protected *callNode.JinjaAST::ASTNode = JinjaAST::NewCallNode(funcName, CurrentLine())

    ; Parse arguments
    If CurrentType() = Jinja::#TK_LParen
      Advance()
      While CurrentType() <> Jinja::#TK_RParen And Not IsAtEnd()
        JinjaAST::AddArg(*callNode, ParseExpression())
        If JinjaError::HasError() : ProcedureReturn *callNode : EndIf
        If CurrentType() = Jinja::#TK_Comma
          Advance()
        EndIf
      Wend
      Expect(Jinja::#TK_RParen)
      If JinjaError::HasError() : ProcedureReturn *callNode : EndIf
    EndIf

    Expect(Jinja::#TK_BlockEnd)
    If JinjaError::HasError() : ProcedureReturn *callNode : EndIf

    ; Skip call body
    While Not IsAtEnd() And Not IsBlockKeyword("endcall")
      If CurrentType() = Jinja::#TK_BlockBegin
        If PeekBlockKeyword() = "endcall"
          Break
        EndIf
      EndIf
      Advance()
    Wend

    Expect(Jinja::#TK_BlockBegin)
    ExpectKeyword("endcall")
    Expect(Jinja::#TK_BlockEnd)

    ProcedureReturn *callNode
  EndProcedure

  ; ===== Block Statement Dispatch =====

  Procedure.i ParseBlockStatement()
    Expect(Jinja::#TK_BlockBegin)
    If JinjaError::HasError() : ProcedureReturn #Null : EndIf

    If CurrentType() = Jinja::#TK_Keyword
      Protected keyword.s = LCase(CurrentValue())

      Select keyword
        Case "if"
          ProcedureReturn ParseIfStatement()
        Case "for"
          ProcedureReturn ParseForStatement()
        Case "block"
          ProcedureReturn ParseBlockDefinition()
        Case "extends"
          ProcedureReturn ParseExtendsStatement()
        Case "set"
          ProcedureReturn ParseSetStatement()
        Case "include"
          ProcedureReturn ParseIncludeStatement()
        Case "macro"
          ProcedureReturn ParseMacroStatement()
        Case "call"
          ProcedureReturn ParseCallStatement()
        Default
          SkipToBlockEnd()
          ProcedureReturn #Null
      EndSelect
    Else
      SkipToBlockEnd()
      ProcedureReturn #Null
    EndIf
  EndProcedure

  ; ===== Expression Parsing =====
  ; Precedence (lowest to highest):
  ;   or -> and -> not -> comparison/in/is -> additive(+,-,~) ->
  ;   multiplicative(*,/,//,%,**) -> unary(-,+) -> postfix(.,[]|,()) -> primary

  Declare.i ParseOrExpression()
  Declare.i ParseAndExpression()
  Declare.i ParseNotExpression()
  Declare.i ParseComparisonExpression()
  Declare.i ParseAdditiveExpression()
  Declare.i ParseMultiplicativeExpression()
  Declare.i ParseUnaryExpression()
  Declare.i ParsePostfixExpression()
  Declare.i ParsePrimaryExpression()

  Procedure.i ParseExpression()
    ; Check for ternary: expr if condition else default
    ; We parse the value first, then check for 'if' keyword
    Protected *expr.JinjaAST::ASTNode = ParseOrExpression()
    If JinjaError::HasError() : ProcedureReturn *expr : EndIf

    ; Handle inline if: value if condition else default
    If CurrentType() = Jinja::#TK_Keyword And LCase(CurrentValue()) = "if"
      Advance() ; skip 'if'
      Protected *condition.JinjaAST::ASTNode = ParseOrExpression()
      If JinjaError::HasError() : ProcedureReturn *expr : EndIf

      Protected *elseExpr.JinjaAST::ASTNode = #Null
      If CurrentType() = Jinja::#TK_Keyword And LCase(CurrentValue()) = "else"
        Advance() ; skip 'else'
        *elseExpr = ParseOrExpression()
        If JinjaError::HasError() : ProcedureReturn *expr : EndIf
      EndIf

      ; Build if node: condition in Left, true value in Body, else in ElseBody
      Protected *ifNode.JinjaAST::ASTNode = JinjaAST::NewIfNode(*condition, CurrentLine())
      ; True branch = the original expression wrapped in output
      JinjaAST::AddChild(*ifNode, *expr)
      If *elseExpr
        JinjaAST::AddElseChild(*ifNode, *elseExpr)
      Else
        ; Default: empty string if no else
        JinjaAST::AddElseChild(*ifNode, JinjaAST::NewLiteralStringNode("", CurrentLine()))
      EndIf
      ProcedureReturn *ifNode
    EndIf

    ProcedureReturn *expr
  EndProcedure

  Procedure.i ParseOrExpression()
    Protected *left.JinjaAST::ASTNode = ParseAndExpression()
    If JinjaError::HasError() : ProcedureReturn *left : EndIf

    While CurrentType() = Jinja::#TK_Keyword And LCase(CurrentValue()) = "or"
      Advance()
      Protected *right.JinjaAST::ASTNode = ParseAndExpression()
      If JinjaError::HasError() : ProcedureReturn *left : EndIf
      *left = JinjaAST::NewBinaryOpNode(*left, "or", *right, CurrentLine())
    Wend

    ProcedureReturn *left
  EndProcedure

  Procedure.i ParseAndExpression()
    Protected *left.JinjaAST::ASTNode = ParseNotExpression()
    If JinjaError::HasError() : ProcedureReturn *left : EndIf

    While CurrentType() = Jinja::#TK_Keyword And LCase(CurrentValue()) = "and"
      Advance()
      Protected *right.JinjaAST::ASTNode = ParseNotExpression()
      If JinjaError::HasError() : ProcedureReturn *left : EndIf
      *left = JinjaAST::NewBinaryOpNode(*left, "and", *right, CurrentLine())
    Wend

    ProcedureReturn *left
  EndProcedure

  Procedure.i ParseNotExpression()
    If CurrentType() = Jinja::#TK_Keyword And LCase(CurrentValue()) = "not"
      Advance()
      Protected *operand.JinjaAST::ASTNode = ParseNotExpression()
      If JinjaError::HasError() : ProcedureReturn #Null : EndIf
      ProcedureReturn JinjaAST::NewUnaryOpNode("not", *operand, CurrentLine())
    EndIf

    ProcedureReturn ParseComparisonExpression()
  EndProcedure

  Procedure.i ParseComparisonExpression()
    Protected *left.JinjaAST::ASTNode = ParseAdditiveExpression()
    If JinjaError::HasError() : ProcedureReturn *left : EndIf

    Protected keepGoing.i = #True
    While keepGoing
      If CurrentType() = Jinja::#TK_Operator
        Protected op.s = CurrentValue()
        If op = "==" Or op = "!=" Or op = "<" Or op = ">" Or op = "<=" Or op = ">="
          Advance()
          Protected *right.JinjaAST::ASTNode = ParseAdditiveExpression()
          If JinjaError::HasError() : ProcedureReturn *left : EndIf
          *left = JinjaAST::NewCompareNode(*left, op, *right, CurrentLine())
        Else
          keepGoing = #False
        EndIf
      ElseIf CurrentType() = Jinja::#TK_Keyword
        Protected kw.s = LCase(CurrentValue())
        If kw = "in"
          Advance()
          Protected *inRight.JinjaAST::ASTNode = ParseAdditiveExpression()
          If JinjaError::HasError() : ProcedureReturn *left : EndIf
          *left = JinjaAST::NewCompareNode(*left, "in", *inRight, CurrentLine())
        ElseIf kw = "not"
          ; Check for "not in"
          If gPos + 1 < gTokenCount And gTokens(gPos + 1)\Type = Jinja::#TK_Keyword And LCase(gTokens(gPos + 1)\Value) = "in"
            Advance() ; skip 'not'
            Advance() ; skip 'in'
            Protected *niRight.JinjaAST::ASTNode = ParseAdditiveExpression()
            If JinjaError::HasError() : ProcedureReturn *left : EndIf
            *left = JinjaAST::NewCompareNode(*left, "not in", *niRight, CurrentLine())
          Else
            keepGoing = #False
          EndIf
        ElseIf kw = "is"
          Advance() ; skip 'is'
          ; Check for "is not"
          If CurrentType() = Jinja::#TK_Keyword And LCase(CurrentValue()) = "not"
            Advance() ; skip 'not'
            Protected *isNotRight.JinjaAST::ASTNode = ParseAdditiveExpression()
            If JinjaError::HasError() : ProcedureReturn *left : EndIf
            *left = JinjaAST::NewCompareNode(*left, "is not", *isNotRight, CurrentLine())
          Else
            Protected *isRight.JinjaAST::ASTNode = ParseAdditiveExpression()
            If JinjaError::HasError() : ProcedureReturn *left : EndIf
            *left = JinjaAST::NewCompareNode(*left, "is", *isRight, CurrentLine())
          EndIf
        Else
          keepGoing = #False
        EndIf
      Else
        keepGoing = #False
      EndIf
    Wend

    ProcedureReturn *left
  EndProcedure

  Procedure.i ParseAdditiveExpression()
    Protected *left.JinjaAST::ASTNode = ParseMultiplicativeExpression()
    If JinjaError::HasError() : ProcedureReturn *left : EndIf

    While CurrentType() = Jinja::#TK_Operator And (CurrentValue() = "+" Or CurrentValue() = "-" Or CurrentValue() = "~")
      Protected aop.s = CurrentValue()
      Advance()
      Protected *aRight.JinjaAST::ASTNode = ParseMultiplicativeExpression()
      If JinjaError::HasError() : ProcedureReturn *left : EndIf
      *left = JinjaAST::NewBinaryOpNode(*left, aop, *aRight, CurrentLine())
    Wend

    ProcedureReturn *left
  EndProcedure

  Procedure.i ParseMultiplicativeExpression()
    Protected *left.JinjaAST::ASTNode = ParseUnaryExpression()
    If JinjaError::HasError() : ProcedureReturn *left : EndIf

    While CurrentType() = Jinja::#TK_Operator And (CurrentValue() = "*" Or CurrentValue() = "/" Or CurrentValue() = "//" Or CurrentValue() = "%" Or CurrentValue() = "**")
      Protected mop.s = CurrentValue()
      Advance()
      Protected *mRight.JinjaAST::ASTNode = ParseUnaryExpression()
      If JinjaError::HasError() : ProcedureReturn *left : EndIf
      *left = JinjaAST::NewBinaryOpNode(*left, mop, *mRight, CurrentLine())
    Wend

    ProcedureReturn *left
  EndProcedure

  Procedure.i ParseUnaryExpression()
    If CurrentType() = Jinja::#TK_Operator And CurrentValue() = "-"
      Advance()
      Protected *operand.JinjaAST::ASTNode = ParsePostfixExpression()
      If JinjaError::HasError() : ProcedureReturn #Null : EndIf
      ProcedureReturn JinjaAST::NewUnaryOpNode("-", *operand, CurrentLine())
    EndIf

    If CurrentType() = Jinja::#TK_Operator And CurrentValue() = "+"
      Advance()
      ProcedureReturn ParsePostfixExpression()
    EndIf

    ProcedureReturn ParsePostfixExpression()
  EndProcedure

  Procedure.i ParsePostfixExpression()
    Protected *expr.JinjaAST::ASTNode = ParsePrimaryExpression()
    If JinjaError::HasError() : ProcedureReturn *expr : EndIf

    Protected running.i = #True
    While running
      If CurrentType() = Jinja::#TK_Dot
        ; Attribute access: expr.name
        Advance()
        If CurrentType() <> Jinja::#TK_Name
          JinjaError::SetError(Jinja::#ERR_Syntax, "Expected attribute name after '.'", CurrentLine())
          ProcedureReturn *expr
        EndIf
        Protected attrName.s = CurrentValue()
        Advance()
        *expr = JinjaAST::NewGetAttrNode(*expr, attrName, CurrentLine())

      ElseIf CurrentType() = Jinja::#TK_LBracket
        ; Item access: expr[index]
        Advance()
        Protected *idx.JinjaAST::ASTNode = ParseExpression()
        If JinjaError::HasError() : ProcedureReturn *expr : EndIf
        Expect(Jinja::#TK_RBracket)
        If JinjaError::HasError() : ProcedureReturn *expr : EndIf
        *expr = JinjaAST::NewGetItemNode(*expr, *idx, CurrentLine())

      ElseIf CurrentType() = Jinja::#TK_Pipe
        ; Filter: expr|filtername or expr|filtername(args)
        Advance()
        If CurrentType() <> Jinja::#TK_Name
          JinjaError::SetError(Jinja::#ERR_Syntax, "Expected filter name after '|'", CurrentLine())
          ProcedureReturn *expr
        EndIf
        Protected filterName.s = CurrentValue()
        Advance()

        Protected *filterNode.JinjaAST::ASTNode = JinjaAST::NewFilterNode(*expr, filterName, CurrentLine())

        ; Parse filter arguments
        If CurrentType() = Jinja::#TK_LParen
          Advance()
          While CurrentType() <> Jinja::#TK_RParen And Not IsAtEnd()
            JinjaAST::AddArg(*filterNode, ParseExpression())
            If JinjaError::HasError() : ProcedureReturn *filterNode : EndIf
            If CurrentType() = Jinja::#TK_Comma
              Advance()
            EndIf
          Wend
          Expect(Jinja::#TK_RParen)
          If JinjaError::HasError() : ProcedureReturn *filterNode : EndIf
        EndIf

        *expr = *filterNode

      ElseIf CurrentType() = Jinja::#TK_LParen
        ; Function call: name(args)
        Advance()
        Protected callName.s = ""
        If *expr\NodeType = Jinja::#NODE_Variable
          callName = *expr\StringVal
        EndIf

        Protected *callNode.JinjaAST::ASTNode = JinjaAST::NewCallNode(callName, CurrentLine())

        While CurrentType() <> Jinja::#TK_RParen And Not IsAtEnd()
          JinjaAST::AddArg(*callNode, ParseExpression())
          If JinjaError::HasError() : ProcedureReturn *callNode : EndIf
          If CurrentType() = Jinja::#TK_Comma
            Advance()
          EndIf
        Wend
        Expect(Jinja::#TK_RParen)
        If JinjaError::HasError() : ProcedureReturn *callNode : EndIf

        *expr = *callNode

      Else
        running = #False
      EndIf
    Wend

    ProcedureReturn *expr
  EndProcedure

  Procedure.i ParsePrimaryExpression()
    Protected lineNum.i = CurrentLine()

    ; Variable name
    If CurrentType() = Jinja::#TK_Name
      Protected name.s = CurrentValue()
      Advance()
      ProcedureReturn JinjaAST::NewVariableNode(name, lineNum)
    EndIf

    ; String literal
    If CurrentType() = Jinja::#TK_String
      Protected strVal.s = CurrentValue()
      Advance()
      ProcedureReturn JinjaAST::NewLiteralStringNode(strVal, lineNum)
    EndIf

    ; Integer literal
    If CurrentType() = Jinja::#TK_Integer
      Protected intVal.q = Val(CurrentValue())
      Advance()
      ProcedureReturn JinjaAST::NewLiteralIntNode(intVal, lineNum)
    EndIf

    ; Float literal
    If CurrentType() = Jinja::#TK_Float
      Protected fltVal.d = ValD(CurrentValue())
      Advance()
      ProcedureReturn JinjaAST::NewLiteralFloatNode(fltVal, lineNum)
    EndIf

    ; Keywords: true, false, none
    If CurrentType() = Jinja::#TK_Keyword
      Protected kw.s = LCase(CurrentValue())
      If kw = "true"
        Advance()
        ProcedureReturn JinjaAST::NewLiteralBoolNode(#True, lineNum)
      ElseIf kw = "false"
        Advance()
        ProcedureReturn JinjaAST::NewLiteralBoolNode(#False, lineNum)
      ElseIf kw = "none"
        Advance()
        ProcedureReturn JinjaAST::NewLiteralNoneNode(lineNum)
      EndIf

      JinjaError::SetError(Jinja::#ERR_Syntax, "Unexpected keyword: " + CurrentValue(), lineNum)
      ProcedureReturn #Null
    EndIf

    ; Parenthesized expression
    If CurrentType() = Jinja::#TK_LParen
      Advance()
      Protected *expr.JinjaAST::ASTNode = ParseExpression()
      If JinjaError::HasError() : ProcedureReturn *expr : EndIf
      Expect(Jinja::#TK_RParen)
      ProcedureReturn *expr
    EndIf

    ; List literal [a, b, c]
    If CurrentType() = Jinja::#TK_LBracket
      Advance()
      Protected *listNode.JinjaAST::ASTNode = JinjaAST::NewListLiteralNode(lineNum)

      While CurrentType() <> Jinja::#TK_RBracket And Not IsAtEnd()
        JinjaAST::AddArg(*listNode, ParseExpression())
        If JinjaError::HasError() : ProcedureReturn *listNode : EndIf
        If CurrentType() = Jinja::#TK_Comma
          Advance()
        EndIf
      Wend

      Expect(Jinja::#TK_RBracket)
      ProcedureReturn *listNode
    EndIf

    JinjaError::SetError(Jinja::#ERR_Syntax, "Unexpected token: " + JinjaToken::TokenName(CurrentType()) + " '" + CurrentValue() + "'", lineNum)
    ProcedureReturn #Null
  EndProcedure

  ; ===== Main Parse Entry Point =====

  Procedure.i Parse(List tokens.JinjaToken::Token())
    ; Clear any previous errors
    JinjaError::ClearError()

    ; Copy tokens to array for random access
    gTokenCount = ListSize(tokens())
    If gTokenCount = 0
      gTokenCount = 1
      ReDim gTokens(0)
      gTokens(0)\Type = Jinja::#TK_EOF
      gTokens(0)\Value = ""
    Else
      ReDim gTokens(gTokenCount - 1)
      Protected i.i = 0
      ForEach tokens()
        gTokens(i)\Type = tokens()\Type
        gTokens(i)\Value = tokens()\Value
        gTokens(i)\LineNumber = tokens()\LineNumber
        gTokens(i)\ColumnNumber = tokens()\ColumnNumber
        i + 1
      Next
    EndIf

    gPos = 0

    ; Build root template node
    Protected *root.JinjaAST::ASTNode = JinjaAST::NewTemplateNode()

    While Not IsAtEnd()
      If JinjaError::HasError()
        Break
      EndIf

      If CurrentType() = Jinja::#TK_Data
        JinjaAST::AddChild(*root, ParseTextNode())
      ElseIf CurrentType() = Jinja::#TK_VariableBegin
        Protected *outNode.JinjaAST::ASTNode = ParseOutputNode()
        If *outNode
          JinjaAST::AddChild(*root, *outNode)
        EndIf
      ElseIf CurrentType() = Jinja::#TK_BlockBegin
        Protected *blockNode.JinjaAST::ASTNode = ParseBlockStatement()
        If *blockNode
          JinjaAST::AddChild(*root, *blockNode)
        EndIf
      Else
        Advance()
      EndIf
    Wend

    ProcedureReturn *root
  EndProcedure

EndModule
