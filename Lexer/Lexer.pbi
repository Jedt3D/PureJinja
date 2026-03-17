; ============================================================================
; PureJinja - Lexer.pbi
; Tokenizer: converts template string into a list of tokens
; Two-mode scanning: outside-block (literal text) / inside-block (expressions)
; ============================================================================
EnableExplicit

DeclareModule JinjaLexer

  ; Tokenize a template string into a list of tokens
  Declare Tokenize(input.s, List tokens.JinjaToken::Token())

EndDeclareModule

Module JinjaLexer

  ; --- Keyword lookup map ---
  Global NewMap gKeywords.i()

  Procedure InitKeywords()
    If MapSize(gKeywords()) = 0
      gKeywords("if") = #True
      gKeywords("elif") = #True
      gKeywords("else") = #True
      gKeywords("endif") = #True
      gKeywords("for") = #True
      gKeywords("endfor") = #True
      gKeywords("in") = #True
      gKeywords("extends") = #True
      gKeywords("block") = #True
      gKeywords("endblock") = #True
      gKeywords("include") = #True
      gKeywords("set") = #True
      gKeywords("macro") = #True
      gKeywords("endmacro") = #True
      gKeywords("call") = #True
      gKeywords("endcall") = #True
      gKeywords("with") = #True
      gKeywords("endwith") = #True
      gKeywords("and") = #True
      gKeywords("or") = #True
      gKeywords("not") = #True
      gKeywords("is") = #True
      gKeywords("true") = #True
      gKeywords("false") = #True
      gKeywords("none") = #True
      gKeywords("raw") = #True
      gKeywords("endraw") = #True
    EndIf
  EndProcedure

  ; --- Helper: Check if character is whitespace ---
  Procedure.i IsWhitespace(ch.s)
    ProcedureReturn Bool(ch = " " Or ch = Chr(9) Or ch = Chr(10) Or ch = Chr(13))
  EndProcedure

  ; --- Helper: Check if character is a digit ---
  Procedure.i IsDigit(ch.s)
    ProcedureReturn Bool(ch >= "0" And ch <= "9")
  EndProcedure

  ; --- Helper: Check if character can start an identifier ---
  Procedure.i IsIdentifierStart(ch.s)
    ProcedureReturn Bool((ch >= "a" And ch <= "z") Or (ch >= "A" And ch <= "Z") Or ch = "_")
  EndProcedure

  ; --- Helper: Check if character can be part of an identifier ---
  Procedure.i IsIdentifierChar(ch.s)
    ProcedureReturn Bool(IsIdentifierStart(ch) Or IsDigit(ch))
  EndProcedure

  ; --- Helper: Add a token to the list ---
  Macro AddToken(tokenList, tType, tValue, tLine, tCol)
    AddElement(tokenList)
    tokenList\Type = tType
    tokenList\Value = tValue
    tokenList\LineNumber = tLine
    tokenList\ColumnNumber = tCol
  EndMacro

  Procedure Tokenize(input.s, List tokens.JinjaToken::Token())
    InitKeywords()
    ClearList(tokens())

    Protected pos.i = 1          ; 1-based position in input string
    Protected lineNum.i = 1
    Protected colNum.i = 1
    Protected inputLen.i = Len(input)
    Protected inBlock.i = #False
    Protected blockType.i = 0    ; 0=none, 1=variable, 2=block
    Protected dataBuffer.s = ""
    Protected ch.s, nextCh.s
    Protected startLine.i, startCol.i

    While pos <= inputLen
      If Not inBlock
        ; === OUTSIDE BLOCK: scan for delimiters or accumulate text ===

        ; Check for {{ (variable begin)
        If pos + 1 <= inputLen And Mid(input, pos, 2) = "{{"
          ; Emit accumulated data
          If dataBuffer <> ""
            AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
            dataBuffer = ""
          EndIf
          AddToken(tokens(), Jinja::#TK_VariableBegin, "{{", lineNum, colNum)
          pos + 2
          colNum + 2
          inBlock = #True
          blockType = 1
          Continue
        EndIf

        ; Check for {% (block begin)
        If pos + 1 <= inputLen And Mid(input, pos, 2) = "{%"
          If dataBuffer <> ""
            AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
            dataBuffer = ""
          EndIf
          AddToken(tokens(), Jinja::#TK_BlockBegin, "{%", lineNum, colNum)
          pos + 2
          colNum + 2
          inBlock = #True
          blockType = 2
          Continue
        EndIf

        ; Check for {# (comment begin) - skip comment entirely
        If pos + 1 <= inputLen And Mid(input, pos, 2) = "{#"
          If dataBuffer <> ""
            AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
            dataBuffer = ""
          EndIf
          pos + 2
          colNum + 2
          ; Skip until #}
          While pos + 1 <= inputLen
            If Mid(input, pos, 2) = "#}"
              pos + 2
              colNum + 2
              Break
            EndIf
            ch = Mid(input, pos, 1)
            If ch = Chr(10)
              lineNum + 1
              colNum = 1
            Else
              colNum + 1
            EndIf
            pos + 1
          Wend
          Continue
        EndIf

        ; Regular character - accumulate
        ch = Mid(input, pos, 1)
        dataBuffer + ch
        If ch = Chr(10)
          lineNum + 1
          colNum = 1
        Else
          colNum + 1
        EndIf
        pos + 1

      Else
        ; === INSIDE BLOCK: scan tokens ===

        ; Skip whitespace
        While pos <= inputLen
          ch = Mid(input, pos, 1)
          If IsWhitespace(ch)
            If ch = Chr(10)
              lineNum + 1
              colNum = 1
            Else
              colNum + 1
            EndIf
            pos + 1
          Else
            Break
          EndIf
        Wend

        If pos > inputLen
          Break
        EndIf

        ; Check for block end delimiters
        If blockType = 1 And pos + 1 <= inputLen And Mid(input, pos, 2) = "}}"
          AddToken(tokens(), Jinja::#TK_VariableEnd, "}}", lineNum, colNum)
          pos + 2
          colNum + 2
          inBlock = #False
          blockType = 0
          Continue
        EndIf

        If blockType = 2 And pos + 1 <= inputLen And Mid(input, pos, 2) = "%}"
          AddToken(tokens(), Jinja::#TK_BlockEnd, "%}", lineNum, colNum)
          pos + 2
          colNum + 2
          inBlock = #False
          blockType = 0
          Continue
        EndIf

        ; Scan token inside block
        ch = Mid(input, pos, 1)
        nextCh = ""
        If pos + 1 <= inputLen
          nextCh = Mid(input, pos + 1, 1)
        EndIf

        ; --- Punctuation and operators ---
        Select ch
          Case "("
            AddToken(tokens(), Jinja::#TK_LParen, "(", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case ")"
            AddToken(tokens(), Jinja::#TK_RParen, ")", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "["
            AddToken(tokens(), Jinja::#TK_LBracket, "[", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "]"
            AddToken(tokens(), Jinja::#TK_RBracket, "]", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case ","
            AddToken(tokens(), Jinja::#TK_Comma, ",", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case ":"
            AddToken(tokens(), Jinja::#TK_Colon, ":", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "|"
            AddToken(tokens(), Jinja::#TK_Pipe, "|", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "."
            AddToken(tokens(), Jinja::#TK_Dot, ".", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "~"
            AddToken(tokens(), Jinja::#TK_Operator, "~", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "+"
            AddToken(tokens(), Jinja::#TK_Operator, "+", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "-"
            AddToken(tokens(), Jinja::#TK_Operator, "-", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue
          Case "%"
            ; Check it's not %} (already handled above)
            AddToken(tokens(), Jinja::#TK_Operator, "%", lineNum, colNum)
            pos + 1 : colNum + 1 : Continue

          Case "="
            If nextCh = "="
              AddToken(tokens(), Jinja::#TK_Operator, "==", lineNum, colNum)
              pos + 2 : colNum + 2
            Else
              AddToken(tokens(), Jinja::#TK_Assign, "=", lineNum, colNum)
              pos + 1 : colNum + 1
            EndIf
            Continue

          Case "!"
            If nextCh = "="
              AddToken(tokens(), Jinja::#TK_Operator, "!=", lineNum, colNum)
              pos + 2 : colNum + 2
            Else
              AddToken(tokens(), Jinja::#TK_Operator, "!", lineNum, colNum)
              pos + 1 : colNum + 1
            EndIf
            Continue

          Case "<"
            If nextCh = "="
              AddToken(tokens(), Jinja::#TK_Operator, "<=", lineNum, colNum)
              pos + 2 : colNum + 2
            Else
              AddToken(tokens(), Jinja::#TK_Operator, "<", lineNum, colNum)
              pos + 1 : colNum + 1
            EndIf
            Continue

          Case ">"
            If nextCh = "="
              AddToken(tokens(), Jinja::#TK_Operator, ">=", lineNum, colNum)
              pos + 2 : colNum + 2
            Else
              AddToken(tokens(), Jinja::#TK_Operator, ">", lineNum, colNum)
              pos + 1 : colNum + 1
            EndIf
            Continue

          Case "*"
            If nextCh = "*"
              AddToken(tokens(), Jinja::#TK_Operator, "**", lineNum, colNum)
              pos + 2 : colNum + 2
            Else
              AddToken(tokens(), Jinja::#TK_Operator, "*", lineNum, colNum)
              pos + 1 : colNum + 1
            EndIf
            Continue

          Case "/"
            If nextCh = "/"
              AddToken(tokens(), Jinja::#TK_Operator, "//", lineNum, colNum)
              pos + 2 : colNum + 2
            Else
              AddToken(tokens(), Jinja::#TK_Operator, "/", lineNum, colNum)
              pos + 1 : colNum + 1
            EndIf
            Continue
        EndSelect

        ; --- String literals ---
        If ch = Chr(34) Or ch = "'"
          Protected quoteChar.s = ch
          startLine = lineNum
          startCol = colNum
          pos + 1 : colNum + 1 ; skip opening quote

          Protected strVal.s = ""
          While pos <= inputLen
            ch = Mid(input, pos, 1)

            ; Handle escape sequences
            If ch = "\"
              If pos + 1 <= inputLen
                Protected escapedCh.s = Mid(input, pos + 1, 1)
                Select escapedCh
                  Case "n"
                    strVal + Chr(10)
                  Case "t"
                    strVal + Chr(9)
                  Case "\"
                    strVal + "\"
                  Case "'"
                    strVal + "'"
                  Case Chr(34)
                    strVal + Chr(34)
                  Default
                    strVal + "\" + escapedCh
                EndSelect
                pos + 2
                colNum + 2
                Continue
              EndIf
            EndIf

            ; End of string
            If ch = quoteChar
              pos + 1 : colNum + 1
              Break
            EndIf

            strVal + ch
            If ch = Chr(10)
              lineNum + 1
              colNum = 1
            Else
              colNum + 1
            EndIf
            pos + 1
          Wend

          AddToken(tokens(), Jinja::#TK_String, strVal, startLine, startCol)
          Continue
        EndIf

        ; --- Numbers ---
        If IsDigit(ch)
          Protected numStr.s = ""
          Protected isFloat.i = #False
          startLine = lineNum
          startCol = colNum

          While pos <= inputLen
            ch = Mid(input, pos, 1)
            If IsDigit(ch)
              numStr + ch
              pos + 1 : colNum + 1
            ElseIf ch = "." And Not isFloat
              ; Check next char is digit (not dot access like 42.something)
              If pos + 1 <= inputLen And IsDigit(Mid(input, pos + 1, 1))
                isFloat = #True
                numStr + "."
                pos + 1 : colNum + 1
              Else
                Break
              EndIf
            Else
              Break
            EndIf
          Wend

          If isFloat
            AddToken(tokens(), Jinja::#TK_Float, numStr, startLine, startCol)
          Else
            AddToken(tokens(), Jinja::#TK_Integer, numStr, startLine, startCol)
          EndIf
          Continue
        EndIf

        ; --- Identifiers and keywords ---
        If IsIdentifierStart(ch)
          Protected ident.s = ""
          startLine = lineNum
          startCol = colNum

          While pos <= inputLen
            ch = Mid(input, pos, 1)
            If IsIdentifierChar(ch)
              ident + ch
              pos + 1 : colNum + 1
            Else
              Break
            EndIf
          Wend

          ; Check if it's a keyword
          If FindMapElement(gKeywords(), LCase(ident))
            AddToken(tokens(), Jinja::#TK_Keyword, ident, startLine, startCol)
          Else
            AddToken(tokens(), Jinja::#TK_Name, ident, startLine, startCol)
          EndIf
          Continue
        EndIf

        ; Unknown character - skip
        pos + 1 : colNum + 1

      EndIf
    Wend

    ; Emit any remaining data buffer
    If dataBuffer <> ""
      AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
    EndIf

    ; Add EOF token
    AddToken(tokens(), Jinja::#TK_EOF, "", lineNum, colNum)
  EndProcedure

EndModule
