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
    tokenList\LStripPrev = #False
    tokenList\RStripNext = #False
  EndMacro

  ; --- Helper: Strip trailing whitespace (spaces, tabs, CR, LF) ---
  Procedure.s StripTrailingWhitespace(s.s)
    Protected i.i = Len(s)
    Protected c.s
    While i > 0
      c = Mid(s, i, 1)
      If c = " " Or c = Chr(9) Or c = Chr(10) Or c = Chr(13)
        i - 1
      Else
        Break
      EndIf
    Wend
    ProcedureReturn Left(s, i)
  EndProcedure

  ; --- Helper: Strip leading whitespace (spaces, tabs, CR, LF) ---
  Procedure.s StripLeadingWhitespace(s.s)
    Protected i.i = 1
    Protected c.s
    While i <= Len(s)
      c = Mid(s, i, 1)
      If c = " " Or c = Chr(9) Or c = Chr(10) Or c = Chr(13)
        i + 1
      Else
        Break
      EndIf
    Wend
    ProcedureReturn Mid(s, i)
  EndProcedure

  ; --- Helper: Check if a {%...%} tag at peekStart is a "raw" tag ---
  ; peekStart points to the character after "{%" (or "{%-")
  ; Returns the position after the closing "%}" if it's {% raw %}, else 0
  Procedure.i CheckRawTag(input.s, inputLen.i, peekStart.i)
    Protected p.i = peekStart
    ; Skip optional "-" (whitespace-control marker)
    If p <= inputLen And Mid(input, p, 1) = "-"
      p + 1
    EndIf
    ; Skip whitespace
    While p <= inputLen And IsWhitespace(Mid(input, p, 1))
      p + 1
    Wend
    ; Check for "raw" keyword (exactly 3 chars, not followed by identifier char)
    If p + 2 <= inputLen And Mid(input, p, 3) = "raw"
      Protected afterRaw.i = p + 3
      If afterRaw > inputLen Or Not IsIdentifierChar(Mid(input, afterRaw, 1))
        ; Find closing %}
        Protected closePos.i = afterRaw
        While closePos + 1 <= inputLen
          If Mid(input, closePos, 2) = "%}"
            ProcedureReturn closePos + 2  ; position after %}
          EndIf
          closePos + 1
        Wend
      EndIf
    EndIf
    ProcedureReturn 0
  EndProcedure

  ; --- Helper: Find {% endraw %} starting at searchFrom ---
  ; Returns the position after the closing "%}" of {% endraw %}, else 0
  Procedure.i FindEndRaw(input.s, inputLen.i, searchFrom.i)
    Protected p.i = searchFrom
    While p <= inputLen
      If p + 1 <= inputLen And Mid(input, p, 2) = "{%"
        Protected erPeek.i = p + 2
        ; Skip optional "-"
        If erPeek <= inputLen And Mid(input, erPeek, 1) = "-"
          erPeek + 1
        EndIf
        ; Skip whitespace
        While erPeek <= inputLen And IsWhitespace(Mid(input, erPeek, 1))
          erPeek + 1
        Wend
        ; Check for "endraw"
        If erPeek + 5 <= inputLen And Mid(input, erPeek, 6) = "endraw"
          Protected afterEndraw.i = erPeek + 6
          If afterEndraw > inputLen Or Not IsIdentifierChar(Mid(input, afterEndraw, 1))
            ; Find closing %}
            Protected erClose.i = afterEndraw
            While erClose <= inputLen And IsWhitespace(Mid(input, erClose, 1))
              erClose + 1
            Wend
            If erClose + 1 <= inputLen And Mid(input, erClose, 2) = "%}"
              ProcedureReturn erClose + 2  ; position after %}
            EndIf
          EndIf
        EndIf
      EndIf
      p + 1
    Wend
    ProcedureReturn 0
  EndProcedure

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

        ; Check for {{ or {{- (variable begin)
        If pos + 1 <= inputLen And Mid(input, pos, 2) = "{{"
          ; Emit accumulated data
          If dataBuffer <> ""
            AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
            dataBuffer = ""
          EndIf
          Protected lstrip_var.i = #False
          If pos + 2 <= inputLen And Mid(input, pos + 2, 1) = "-"
            lstrip_var = #True
            AddToken(tokens(), Jinja::#TK_VariableBegin, "{{-", lineNum, colNum)
            pos + 3
            colNum + 3
          Else
            AddToken(tokens(), Jinja::#TK_VariableBegin, "{{", lineNum, colNum)
            pos + 2
            colNum + 2
          EndIf
          If lstrip_var
            ; Mark this token as stripping the previous text
            tokens()\LStripPrev = #True
          EndIf
          inBlock = #True
          blockType = 1
          Continue
        EndIf

        ; Check for {% or {%- (block begin) — also handles {% raw %}...{% endraw %}
        If pos + 1 <= inputLen And Mid(input, pos, 2) = "{%"
          ; --- Check if this is a {% raw %} block ---
          Protected rawContentEnd.i = CheckRawTag(input, inputLen, pos + 2)
          If rawContentEnd > 0
            ; rawContentEnd is the position where raw content starts (after the %} of {% raw %})
            ; Find {% endraw %}
            Protected endRawAfter.i = FindEndRaw(input, inputLen, rawContentEnd)
            If endRawAfter > 0
              ; Raw content spans from rawContentEnd to just before the {% endraw %} tag
              ; We need to find where {% endraw %} starts (work backwards from endRawAfter)
              ; The content is input[rawContentEnd .. endRawStartPos-1]
              ; To find endRawStartPos: scan forward from rawContentEnd for the {%
              Protected endRawStart.i = rawContentEnd
              Protected erScan.i = rawContentEnd
              While erScan <= inputLen
                If erScan + 1 <= inputLen And Mid(input, erScan, 2) = "{%"
                  Protected erPeekCheck.i = erScan + 2
                  ; Skip optional "-"
                  If erPeekCheck <= inputLen And Mid(input, erPeekCheck, 1) = "-"
                    erPeekCheck + 1
                  EndIf
                  ; Skip whitespace
                  While erPeekCheck <= inputLen And IsWhitespace(Mid(input, erPeekCheck, 1))
                    erPeekCheck + 1
                  Wend
                  If erPeekCheck + 5 <= inputLen And Mid(input, erPeekCheck, 6) = "endraw"
                    Protected afterErCheck.i = erPeekCheck + 6
                    If afterErCheck > inputLen Or Not IsIdentifierChar(Mid(input, afterErCheck, 1))
                      endRawStart = erScan
                      Break
                    EndIf
                  EndIf
                EndIf
                erScan + 1
              Wend
              ; Extract raw content
              Protected rawContent.s = Mid(input, rawContentEnd, endRawStart - rawContentEnd)
              ; Emit pending data buffer
              If dataBuffer <> ""
                AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
                dataBuffer = ""
              EndIf
              ; Emit raw content as TK_Data (even if empty — pass 3 will remove empty ones,
              ; but that is acceptable since empty raw block produces empty output anyway)
              If rawContent <> ""
                AddToken(tokens(), Jinja::#TK_Data, rawContent, lineNum, colNum)
              EndIf
              ; Update line/col by scanning through all consumed characters
              Protected rawScanIdx.i
              Protected rawScanCh.s
              For rawScanIdx = pos To endRawAfter - 1
                rawScanCh = Mid(input, rawScanIdx, 1)
                If rawScanCh = Chr(10)
                  lineNum + 1
                  colNum = 1
                Else
                  colNum + 1
                EndIf
              Next rawScanIdx
              pos = endRawAfter
              Continue
            EndIf
          EndIf
          ; --- Normal {%...%} block begin ---
          If dataBuffer <> ""
            AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
            dataBuffer = ""
          EndIf
          Protected lstrip_blk.i = #False
          If pos + 2 <= inputLen And Mid(input, pos + 2, 1) = "-"
            lstrip_blk = #True
            AddToken(tokens(), Jinja::#TK_BlockBegin, "{%-", lineNum, colNum)
            pos + 3
            colNum + 3
          Else
            AddToken(tokens(), Jinja::#TK_BlockBegin, "{%", lineNum, colNum)
            pos + 2
            colNum + 2
          EndIf
          If lstrip_blk
            tokens()\LStripPrev = #True
          EndIf
          inBlock = #True
          blockType = 2
          Continue
        EndIf

        ; Check for {# or {#- (comment begin) - skip comment entirely
        If pos + 1 <= inputLen And Mid(input, pos, 2) = "{#"
          ; Determine if {#- (strip before comment)
          Protected lstrip_cmt.i = #False
          If pos + 2 <= inputLen And Mid(input, pos + 2, 1) = "-"
            lstrip_cmt = #True
          EndIf
          ; Strip trailing whitespace from dataBuffer if {#-
          If lstrip_cmt And dataBuffer <> ""
            dataBuffer = StripTrailingWhitespace(dataBuffer)
          EndIf
          If dataBuffer <> ""
            AddToken(tokens(), Jinja::#TK_Data, dataBuffer, lineNum, colNum)
            dataBuffer = ""
          EndIf
          pos + 2
          colNum + 2
          ; Skip until #} or -#}
          Protected rstrip_cmt.i = #False
          While pos + 1 <= inputLen
            If Mid(input, pos, 2) = "#}"
              pos + 2
              colNum + 2
              Break
            EndIf
            ; Check for -#} (strip after comment)
            If pos + 2 <= inputLen And Mid(input, pos, 3) = "-#}"
              rstrip_cmt = #True
              pos + 3
              colNum + 3
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
          ; If -#}: mark that we need to strip leading whitespace from next text
          ; We emit a sentinel TK_Data token of "" with RStripNext so the
          ; post-processing pass can pick it up. Actually we use a flag variable.
          If rstrip_cmt
            ; We need to strip next text token - track this via a dummy token approach
            ; Instead: set a pending flag that gets applied to the next data buffer
            ; We use a simpler approach: add the data stripped inline when it's emitted
            ; Set a flag via a special empty data token with RStripNext
            AddToken(tokens(), Jinja::#TK_Data, "", lineNum, colNum)
            tokens()\RStripNext = #True
          EndIf
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

        ; Check for block end delimiters: -}} or }}
        If blockType = 1 And pos + 1 <= inputLen And Mid(input, pos, 2) = "}}"
          AddToken(tokens(), Jinja::#TK_VariableEnd, "}}", lineNum, colNum)
          tokens()\RStripNext = #False
          pos + 2
          colNum + 2
          inBlock = #False
          blockType = 0
          Continue
        EndIf
        ; Check for -}} (strip after variable)
        If blockType = 1 And ch = "-" And pos + 2 <= inputLen And Mid(input, pos + 1, 2) = "}}"
          AddToken(tokens(), Jinja::#TK_VariableEnd, "-}}", lineNum, colNum)
          tokens()\RStripNext = #True
          pos + 3
          colNum + 3
          inBlock = #False
          blockType = 0
          Continue
        EndIf

        ; Check for block end: %}  or -%}
        If blockType = 2 And pos + 1 <= inputLen And Mid(input, pos, 2) = "%}"
          AddToken(tokens(), Jinja::#TK_BlockEnd, "%}", lineNum, colNum)
          tokens()\RStripNext = #False
          pos + 2
          colNum + 2
          inBlock = #False
          blockType = 0
          Continue
        EndIf
        ; Check for -%} (strip after block)
        If blockType = 2 And ch = "-" And pos + 2 <= inputLen And Mid(input, pos + 1, 2) = "%}"
          AddToken(tokens(), Jinja::#TK_BlockEnd, "-%}", lineNum, colNum)
          tokens()\RStripNext = #True
          pos + 3
          colNum + 3
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

    ; =========================================================================
    ; Post-processing pass: apply whitespace strip markers
    ;
    ; Walk the token list. For each token with LStripPrev=True, find the
    ; nearest preceding TK_Data token and strip its trailing whitespace.
    ; For each token with RStripNext=True, find the nearest following TK_Data
    ; token and strip its leading whitespace.
    ; =========================================================================
    If FirstElement(tokens())
      ; Pass 1: LStripPrev — strip trailing whitespace from preceding TK_Data
      ForEach tokens()
        If tokens()\LStripPrev
          ; Walk backwards to find a TK_Data token
          If PreviousElement(tokens())
            ; Skip empty TK_Data tokens that are just sentinels
            While tokens()\Type = Jinja::#TK_Data And tokens()\Value = "" And tokens()\RStripNext = #False
              If Not PreviousElement(tokens())
                Break
              EndIf
            Wend
            If tokens()\Type = Jinja::#TK_Data
              tokens()\Value = StripTrailingWhitespace(tokens()\Value)
            EndIf
            NextElement(tokens())
          EndIf
        EndIf
      Next

      ; Pass 2: RStripNext — strip leading whitespace from following TK_Data
      ForEach tokens()
        If tokens()\RStripNext
          ; Walk forwards to find a TK_Data token
          If NextElement(tokens())
            ; Skip non-data tokens (there should be none between end delimiter and next text,
            ; but handle the case where there's an empty sentinel TK_Data too)
            While tokens()\Type = Jinja::#TK_Data And tokens()\Value = "" And tokens()\RStripNext = #True
              If Not NextElement(tokens())
                Break
              EndIf
            Wend
            If tokens()\Type = Jinja::#TK_Data
              tokens()\Value = StripLeadingWhitespace(tokens()\Value)
            EndIf
            PreviousElement(tokens())
          EndIf
        EndIf
      Next

      ; Pass 3: Remove empty TK_Data tokens that were sentinel RStripNext markers
      ; (empty data tokens with RStripNext=True that remain after stripping)
      ; Also remove any TK_Data tokens that became empty after stripping
      ; (only the sentinel ones — we keep legit empty strings if they came from the template)
      ; Actually we remove all TK_Data tokens with empty value since they add nothing to output.
      ; Re-iterate and delete empty TK_Data tokens
      ForEach tokens()
        If tokens()\Type = Jinja::#TK_Data And tokens()\Value = ""
          DeleteElement(tokens())
        EndIf
      Next
    EndIf

  EndProcedure

EndModule
