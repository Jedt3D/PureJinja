; ============================================================================
; PureJinja - Filters.pbi
; Built-in filter implementations for Jinja2 template engine
; Filters transform values: {{ value|filtername(args) }}
; ============================================================================
EnableExplicit

DeclareModule JinjaFilters

  ; Register all built-in filters into a filter map
  ; Map key = filter name, value = procedure address
  Declare RegisterAll(Map filters.i())

  ; --- Individual filter procedures ---
  ; All filters take: *value.JinjaVariant, *args (linked list of JinjaVariant), argCount.i
  ; All filters write result to *result.JinjaVariant

  Declare FilterUpper(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterLower(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterTitle(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterCapitalize(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterTrim(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterLength(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterDefault(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterInt(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterFloat(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterString(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterJoin(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterReplace(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterFirst(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterLast(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterReverse(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterSort(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterEscape(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterSafe(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterAbs(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterRound(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterList(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterBatch(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterWordcount(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterTruncate(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
  Declare FilterStriptags(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)

EndDeclareModule

Module JinjaFilters

  ; --- Helper: Get argument at index from linked list of variants ---
  ; Args are stored as an array of JinjaVariant that we access by offset
  Procedure.i GetArg(*args.JinjaVariant::JinjaVariant, index.i, argCount.i, *out.JinjaVariant::JinjaVariant)
    If *args = #Null Or index >= argCount Or index < 0
      JinjaVariant::NullVariant(*out)
      ProcedureReturn #False
    EndIf
    ; Args are stored contiguously (array of JinjaVariant structures)
    Protected *arg.JinjaVariant::JinjaVariant = *args + (index * SizeOf(JinjaVariant::JinjaVariant))
    JinjaVariant::CopyVariant(*out, *arg)
    ProcedureReturn #True
  EndProcedure

  ; --- Helper: PureBasic Title Case ---
  Procedure.s TitleCase(input.s)
    Protected result.s = ""
    Protected inWord.i = #False
    Protected i.i
    Protected ch.s

    For i = 1 To Len(input)
      ch = Mid(input, i, 1)
      If ch = " " Or ch = Chr(9) Or ch = Chr(10) Or ch = Chr(13) Or ch = "-" Or ch = "_"
        result + ch
        inWord = #False
      ElseIf Not inWord
        result + UCase(ch)
        inWord = #True
      Else
        result + LCase(ch)
      EndIf
    Next

    ProcedureReturn result
  EndProcedure

  ; ===== Filter Registration =====

  Procedure RegisterAll(Map filters.i())
    filters("upper") = @FilterUpper()
    filters("lower") = @FilterLower()
    filters("title") = @FilterTitle()
    filters("capitalize") = @FilterCapitalize()
    filters("trim") = @FilterTrim()
    filters("length") = @FilterLength()
    filters("count") = @FilterLength()       ; alias
    filters("default") = @FilterDefault()
    filters("d") = @FilterDefault()           ; alias
    filters("int") = @FilterInt()
    filters("float") = @FilterFloat()
    filters("string") = @FilterString()
    filters("join") = @FilterJoin()
    filters("replace") = @FilterReplace()
    filters("first") = @FilterFirst()
    filters("last") = @FilterLast()
    filters("reverse") = @FilterReverse()
    filters("sort") = @FilterSort()
    filters("escape") = @FilterEscape()
    filters("e") = @FilterEscape()            ; alias
    filters("safe") = @FilterSafe()
    filters("abs") = @FilterAbs()
    filters("round") = @FilterRound()
    filters("list") = @FilterList()
    filters("batch") = @FilterBatch()
    filters("wordcount") = @FilterWordcount()
    filters("truncate") = @FilterTruncate()
    filters("striptags") = @FilterStriptags()
  EndProcedure

  ; ===== Filter Implementations =====

  Procedure FilterUpper(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::StrVariant(*result, UCase(JinjaVariant::ToString(*value)))
  EndProcedure

  Procedure FilterLower(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::StrVariant(*result, LCase(JinjaVariant::ToString(*value)))
  EndProcedure

  Procedure FilterTitle(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::StrVariant(*result, TitleCase(JinjaVariant::ToString(*value)))
  EndProcedure

  Procedure FilterCapitalize(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    Protected s.s = JinjaVariant::ToString(*value)
    If Len(s) = 0
      JinjaVariant::StrVariant(*result, "")
    Else
      JinjaVariant::StrVariant(*result, UCase(Left(s, 1)) + LCase(Mid(s, 2)))
    EndIf
  EndProcedure

  Procedure FilterTrim(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::StrVariant(*result, Trim(JinjaVariant::ToString(*value)))
  EndProcedure

  Procedure FilterLength(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    If *value\VType = Jinja::#VT_List
      JinjaVariant::IntVariant(*result, JinjaVariant::VListSize(*value))
    ElseIf *value\VType = Jinja::#VT_Map
      JinjaVariant::IntVariant(*result, JinjaVariant::VMapSize(*value))
    Else
      JinjaVariant::IntVariant(*result, Len(JinjaVariant::ToString(*value)))
    EndIf
  EndProcedure

  Procedure FilterDefault(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Return default value if value is null or empty string
    Protected isEmpty.i = #False
    If *value\VType = Jinja::#VT_Null
      isEmpty = #True
    ElseIf *value\VType = Jinja::#VT_String And *value\StrVal = ""
      isEmpty = #True
    EndIf

    If isEmpty
      Protected defVal.JinjaVariant::JinjaVariant
      If GetArg(*args, 0, argCount, @defVal)
        JinjaVariant::CopyVariant(*result, @defVal)
        JinjaVariant::FreeVariant(@defVal)
      Else
        JinjaVariant::StrVariant(*result, "")
      EndIf
    Else
      JinjaVariant::CopyVariant(*result, *value)
    EndIf
  EndProcedure

  Procedure FilterInt(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::IntVariant(*result, JinjaVariant::ToInteger(*value))
  EndProcedure

  Procedure FilterFloat(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::DblVariant(*result, JinjaVariant::ToDouble(*value))
  EndProcedure

  Procedure FilterString(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::StrVariant(*result, JinjaVariant::ToString(*value))
  EndProcedure

  Procedure FilterJoin(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Join list items with separator
    Protected sep.s = ""
    Protected sepVar.JinjaVariant::JinjaVariant
    If GetArg(*args, 0, argCount, @sepVar)
      sep = JinjaVariant::ToString(@sepVar)
      JinjaVariant::FreeVariant(@sepVar)
    EndIf

    If *value\VType = Jinja::#VT_List
      Protected output.s = ""
      Protected count.i = JinjaVariant::VListSize(*value)
      Protected i.i
      Protected itemV.JinjaVariant::JinjaVariant
      For i = 0 To count - 1
        If i > 0
          output + sep
        EndIf
        JinjaVariant::VListGet(*value, i, @itemV)
        output + JinjaVariant::ToString(@itemV)
        JinjaVariant::FreeVariant(@itemV)
      Next
      JinjaVariant::StrVariant(*result, output)
    Else
      JinjaVariant::StrVariant(*result, JinjaVariant::ToString(*value))
    EndIf
  EndProcedure

  Procedure FilterReplace(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    Protected s.s = JinjaVariant::ToString(*value)
    Protected searchVar.JinjaVariant::JinjaVariant
    Protected replaceVar.JinjaVariant::JinjaVariant

    If argCount >= 2
      GetArg(*args, 0, argCount, @searchVar)
      GetArg(*args, 1, argCount, @replaceVar)
      s = ReplaceString(s, JinjaVariant::ToString(@searchVar), JinjaVariant::ToString(@replaceVar))
      JinjaVariant::FreeVariant(@searchVar)
      JinjaVariant::FreeVariant(@replaceVar)
    EndIf

    JinjaVariant::StrVariant(*result, s)
  EndProcedure

  Procedure FilterFirst(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    If *value\VType = Jinja::#VT_List
      If JinjaVariant::VListSize(*value) > 0
        JinjaVariant::VListGet(*value, 0, *result)
      Else
        JinjaVariant::NullVariant(*result)
      EndIf
    Else
      Protected s.s = JinjaVariant::ToString(*value)
      If Len(s) > 0
        JinjaVariant::StrVariant(*result, Left(s, 1))
      Else
        JinjaVariant::StrVariant(*result, "")
      EndIf
    EndIf
  EndProcedure

  Procedure FilterLast(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    If *value\VType = Jinja::#VT_List
      Protected count.i = JinjaVariant::VListSize(*value)
      If count > 0
        JinjaVariant::VListGet(*value, count - 1, *result)
      Else
        JinjaVariant::NullVariant(*result)
      EndIf
    Else
      Protected s.s = JinjaVariant::ToString(*value)
      If Len(s) > 0
        JinjaVariant::StrVariant(*result, Right(s, 1))
      Else
        JinjaVariant::StrVariant(*result, "")
      EndIf
    EndIf
  EndProcedure

  Procedure FilterReverse(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    If *value\VType = Jinja::#VT_List
      ; Reverse a list
      Protected count.i = JinjaVariant::VListSize(*value)
      JinjaVariant::NewListVariant(*result)
      Protected i.i
      Protected itemV.JinjaVariant::JinjaVariant
      For i = count - 1 To 0 Step -1
        JinjaVariant::VListGet(*value, i, @itemV)
        JinjaVariant::VListAdd(*result, @itemV)
        JinjaVariant::FreeVariant(@itemV)
      Next
    Else
      ; Reverse a string
      Protected s.s = JinjaVariant::ToString(*value)
      Protected rev.s = ""
      For i = Len(s) To 1 Step -1
        rev + Mid(s, i, 1)
      Next
      JinjaVariant::StrVariant(*result, rev)
    EndIf
  EndProcedure

  Procedure FilterSort(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Simple bubble sort for list variants
    If *value\VType = Jinja::#VT_List
      Protected count.i = JinjaVariant::VListSize(*value)
      ; Copy all items to temp array
      Protected Dim tempArr.JinjaVariant::JinjaVariant(count - 1)
      Protected i.i
      For i = 0 To count - 1
        JinjaVariant::VListGet(*value, i, @tempArr(i))
      Next

      ; Bubble sort
      Protected j.i, swapped.i
      For i = 0 To count - 2
        swapped = #False
        For j = 0 To count - 2 - i
          If JinjaVariant::CompareVariants(@tempArr(j), @tempArr(j + 1)) > 0
            ; Swap
            Protected temp.JinjaVariant::JinjaVariant
            CopyMemory(@tempArr(j), @temp, SizeOf(JinjaVariant::JinjaVariant))
            CopyMemory(@tempArr(j + 1), @tempArr(j), SizeOf(JinjaVariant::JinjaVariant))
            CopyMemory(@temp, @tempArr(j + 1), SizeOf(JinjaVariant::JinjaVariant))
            swapped = #True
          EndIf
        Next
        If Not swapped
          Break
        EndIf
      Next

      ; Build result list
      JinjaVariant::NewListVariant(*result)
      For i = 0 To count - 1
        JinjaVariant::VListAdd(*result, @tempArr(i))
      Next

      ; Free temp array items
      For i = 0 To count - 1
        JinjaVariant::FreeVariant(@tempArr(i))
      Next
    Else
      JinjaVariant::CopyVariant(*result, *value)
    EndIf
  EndProcedure

  Procedure FilterEscape(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Explicitly escape HTML and mark as Markup
    Protected s.s = JinjaVariant::ToString(*value)
    If *value\VType = Jinja::#VT_Markup
      ; Already safe
      JinjaVariant::MarkupVariant(*result, s)
    Else
      JinjaVariant::MarkupVariant(*result, JinjaMarkup::EscapeHTML(s))
    EndIf
  EndProcedure

  Procedure FilterSafe(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Mark value as safe (no auto-escaping)
    JinjaVariant::MarkupVariant(*result, JinjaVariant::ToString(*value))
  EndProcedure

  Procedure FilterAbs(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    Protected d.d = JinjaVariant::ToDouble(*value)
    If d < 0
      d = -d
    EndIf
    If *value\VType = Jinja::#VT_Integer
      JinjaVariant::IntVariant(*result, Abs(*value\IntVal))
    Else
      JinjaVariant::DblVariant(*result, d)
    EndIf
  EndProcedure

  Procedure FilterRound(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    Protected precision.i = 0
    Protected precVar.JinjaVariant::JinjaVariant
    If GetArg(*args, 0, argCount, @precVar)
      precision = JinjaVariant::ToInteger(@precVar)
      JinjaVariant::FreeVariant(@precVar)
    EndIf

    Protected d.d = JinjaVariant::ToDouble(*value)
    Protected factor.d = Pow(10, precision)
    d = Round(d * factor, #PB_Round_Nearest) / factor

    If precision = 0
      JinjaVariant::IntVariant(*result, Int(d))
    Else
      JinjaVariant::DblVariant(*result, d)
    EndIf
  EndProcedure

  Procedure FilterList(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Convert string to list of characters, or pass through lists
    If *value\VType = Jinja::#VT_List
      JinjaVariant::CopyVariant(*result, *value)
    Else
      Protected s.s = JinjaVariant::ToString(*value)
      JinjaVariant::NewListVariant(*result)
      Protected i.i
      Protected chVar.JinjaVariant::JinjaVariant
      For i = 1 To Len(s)
        JinjaVariant::StrVariant(@chVar, Mid(s, i, 1))
        JinjaVariant::VListAdd(*result, @chVar)
      Next
    EndIf
  EndProcedure

  Procedure FilterBatch(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Split a list into batches of N items
    Protected batchSize.i = 1
    Protected bsVar.JinjaVariant::JinjaVariant
    If GetArg(*args, 0, argCount, @bsVar)
      batchSize = JinjaVariant::ToInteger(@bsVar)
      JinjaVariant::FreeVariant(@bsVar)
      If batchSize < 1
        batchSize = 1
      EndIf
    EndIf

    JinjaVariant::NewListVariant(*result)

    If *value\VType = Jinja::#VT_List
      Protected count.i = JinjaVariant::VListSize(*value)
      Protected i.i
      Protected batchV.JinjaVariant::JinjaVariant
      Protected itemV.JinjaVariant::JinjaVariant

      For i = 0 To count - 1
        If i % batchSize = 0
          ; Start new batch
          If i > 0
            JinjaVariant::VListAdd(*result, @batchV)
            JinjaVariant::FreeVariant(@batchV)
          EndIf
          JinjaVariant::NewListVariant(@batchV)
        EndIf
        JinjaVariant::VListGet(*value, i, @itemV)
        JinjaVariant::VListAdd(@batchV, @itemV)
        JinjaVariant::FreeVariant(@itemV)
      Next

      ; Add last batch
      If count > 0
        JinjaVariant::VListAdd(*result, @batchV)
        JinjaVariant::FreeVariant(@batchV)
      EndIf
    EndIf
  EndProcedure

  Procedure FilterWordcount(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    Protected s.s = Trim(JinjaVariant::ToString(*value))
    If s = ""
      JinjaVariant::IntVariant(*result, 0)
      ProcedureReturn
    EndIf

    Protected wordCount.i = 1
    Protected inSpace.i = #False
    Protected i.i
    Protected ch.s
    For i = 1 To Len(s)
      ch = Mid(s, i, 1)
      If ch = " " Or ch = Chr(9) Or ch = Chr(10) Or ch = Chr(13)
        If Not inSpace
          wordCount + 1
          inSpace = #True
        EndIf
      Else
        inSpace = #False
      EndIf
    Next
    JinjaVariant::IntVariant(*result, wordCount)
  EndProcedure

  Procedure FilterTruncate(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    Protected maxLen.i = 255
    Protected lenVar.JinjaVariant::JinjaVariant
    If GetArg(*args, 0, argCount, @lenVar)
      maxLen = JinjaVariant::ToInteger(@lenVar)
      JinjaVariant::FreeVariant(@lenVar)
    EndIf

    Protected s.s = JinjaVariant::ToString(*value)
    If Len(s) > maxLen
      JinjaVariant::StrVariant(*result, Left(s, maxLen) + "...")
    Else
      JinjaVariant::StrVariant(*result, s)
    EndIf
  EndProcedure

  Procedure FilterStriptags(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)
    ; Remove HTML tags from a string
    Protected s.s = JinjaVariant::ToString(*value)
    Protected output.s = ""
    Protected inTag.i = #False
    Protected i.i
    Protected ch.s

    For i = 1 To Len(s)
      ch = Mid(s, i, 1)
      If ch = "<"
        inTag = #True
      ElseIf ch = ">"
        inTag = #False
      ElseIf Not inTag
        output + ch
      EndIf
    Next

    JinjaVariant::StrVariant(*result, output)
  EndProcedure

EndModule
