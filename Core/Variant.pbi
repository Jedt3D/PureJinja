; ============================================================================
; PureJinja - Variant.pbi
; Dynamic type system for template variables and expression results
; Implements: JinjaVariant structure, constructors, conversions, comparisons
; ============================================================================
EnableExplicit

XIncludeFile "Constants.pbi"
XIncludeFile "Error.pbi"

DeclareModule JinjaVariant

  ; --- JinjaVariant Structure ---
  ; Tagged union representing any Jinja value
  Structure JinjaVariant
    VType.i         ; VariantType enum
    IntVal.q        ; Integer/Boolean storage (q = quad/64-bit)
    DblVal.d        ; Double storage
    StrVal.s        ; String storage (also used for Markup)
    *ListPtr        ; Pointer to List of JinjaVariant (when VType = #VT_List)
    *MapPtr         ; Pointer to Map of JinjaVariant (when VType = #VT_Map)
  EndStructure

  ; --- Constructors ---
  Declare NullVariant(*out.JinjaVariant)
  Declare BoolVariant(*out.JinjaVariant, value.i)
  Declare IntVariant(*out.JinjaVariant, value.q)
  Declare DblVariant(*out.JinjaVariant, value.d)
  Declare StrVariant(*out.JinjaVariant, value.s)
  Declare MarkupVariant(*out.JinjaVariant, value.s)
  Declare.i NewListVariant(*out.JinjaVariant)
  Declare.i NewMapVariant(*out.JinjaVariant)

  ; --- Conversions ---
  Declare.s ToString(*v.JinjaVariant)
  Declare.d ToDouble(*v.JinjaVariant)
  Declare.q ToInteger(*v.JinjaVariant)
  Declare.i IsTruthy(*v.JinjaVariant)

  ; --- Comparison ---
  Declare.i VariantsEqual(*a.JinjaVariant, *b.JinjaVariant)
  Declare.i CompareVariants(*a.JinjaVariant, *b.JinjaVariant)

  ; --- Memory Management ---
  Declare CopyVariant(*dst.JinjaVariant, *src.JinjaVariant)
  Declare FreeVariant(*v.JinjaVariant)
  Declare FreeVariantList(*listPtr)
  Declare FreeVariantMap(*mapPtr)

  ; --- List Operations ---
  Declare.i VListSize(*v.JinjaVariant)
  Declare.i VListGet(*v.JinjaVariant, index.i, *out.JinjaVariant)
  Declare VListAdd(*v.JinjaVariant, *item.JinjaVariant)

  ; --- Map Operations ---
  Declare.i VMapGet(*v.JinjaVariant, key.s, *out.JinjaVariant)
  Declare VMapSet(*v.JinjaVariant, key.s, *item.JinjaVariant)
  Declare.i VMapHasKey(*v.JinjaVariant, key.s)
  Declare.i VMapSize(*v.JinjaVariant)
  Declare VMapKeys(*v.JinjaVariant, List keys.s())

  ; --- Type Name (for debugging) ---
  Declare.s TypeName(vtype.i)

EndDeclareModule

Module JinjaVariant

  ; ===== Internal list/map structure wrappers =====
  ; We use NewList/NewMap allocated via pointers

  Structure VariantListWrapper
    List Items.JinjaVariant()
  EndStructure

  Structure VariantMapWrapper
    Map Entries.JinjaVariant()
  EndStructure

  ; ===== Constructors =====

  Procedure NullVariant(*out.JinjaVariant)
    *out\VType = Jinja::#VT_None
    *out\IntVal = 0
    *out\DblVal = 0.0
    *out\StrVal = ""
    *out\ListPtr = #Null
    *out\MapPtr = #Null
  EndProcedure

  Procedure BoolVariant(*out.JinjaVariant, value.i)
    *out\VType = Jinja::#VT_Boolean
    If value
      *out\IntVal = 1
    Else
      *out\IntVal = 0
    EndIf
    *out\DblVal = 0.0
    *out\StrVal = ""
    *out\ListPtr = #Null
    *out\MapPtr = #Null
  EndProcedure

  Procedure IntVariant(*out.JinjaVariant, value.q)
    *out\VType = Jinja::#VT_Integer
    *out\IntVal = value
    *out\DblVal = 0.0
    *out\StrVal = ""
    *out\ListPtr = #Null
    *out\MapPtr = #Null
  EndProcedure

  Procedure DblVariant(*out.JinjaVariant, value.d)
    *out\VType = Jinja::#VT_Double
    *out\IntVal = 0
    *out\DblVal = value
    *out\StrVal = ""
    *out\ListPtr = #Null
    *out\MapPtr = #Null
  EndProcedure

  Procedure StrVariant(*out.JinjaVariant, value.s)
    *out\VType = Jinja::#VT_String
    *out\IntVal = 0
    *out\DblVal = 0.0
    *out\StrVal = value
    *out\ListPtr = #Null
    *out\MapPtr = #Null
  EndProcedure

  Procedure MarkupVariant(*out.JinjaVariant, value.s)
    *out\VType = Jinja::#VT_Markup
    *out\IntVal = 0
    *out\DblVal = 0.0
    *out\StrVal = value
    *out\ListPtr = #Null
    *out\MapPtr = #Null
  EndProcedure

  Procedure.i NewListVariant(*out.JinjaVariant)
    ; Creates a new list variant with an allocated list wrapper
    Protected *wrapper.VariantListWrapper = AllocateStructure(VariantListWrapper)
    If *wrapper = #Null
      ProcedureReturn #False
    EndIf
    *out\VType = Jinja::#VT_List
    *out\IntVal = 0
    *out\DblVal = 0.0
    *out\StrVal = ""
    *out\ListPtr = *wrapper
    *out\MapPtr = #Null
    ProcedureReturn #True
  EndProcedure

  Procedure.i NewMapVariant(*out.JinjaVariant)
    ; Creates a new map variant with an allocated map wrapper
    Protected *wrapper.VariantMapWrapper = AllocateStructure(VariantMapWrapper)
    If *wrapper = #Null
      ProcedureReturn #False
    EndIf
    *out\VType = Jinja::#VT_Map
    *out\IntVal = 0
    *out\DblVal = 0.0
    *out\StrVal = ""
    *out\ListPtr = #Null
    *out\MapPtr = *wrapper
    ProcedureReturn #True
  EndProcedure

  ; ===== Conversions =====

  Procedure.s ToString(*v.JinjaVariant)
    If *v = #Null
      ProcedureReturn ""
    EndIf

    Select *v\VType
      Case Jinja::#VT_None
        ProcedureReturn ""

      Case Jinja::#VT_Boolean
        If *v\IntVal
          ProcedureReturn "True"
        Else
          ProcedureReturn "False"
        EndIf

      Case Jinja::#VT_Integer
        ProcedureReturn Str(*v\IntVal)

      Case Jinja::#VT_Double
        ; Format double - remove trailing zeros for clean output
        Protected dStr.s = StrD(*v\DblVal, 10)
        ; Trim trailing zeros after decimal point
        If FindString(dStr, ".")
          While Right(dStr, 1) = "0"
            dStr = Left(dStr, Len(dStr) - 1)
          Wend
          If Right(dStr, 1) = "."
            dStr + "0"
          EndIf
        EndIf
        ProcedureReturn dStr

      Case Jinja::#VT_String
        ProcedureReturn *v\StrVal

      Case Jinja::#VT_Markup
        ProcedureReturn *v\StrVal

      Case Jinja::#VT_List
        ; Render list as [item1, item2, ...]
        Protected result.s = "["
        Protected *wrapper.VariantListWrapper = *v\ListPtr
        If *wrapper
          Protected first.i = #True
          ForEach *wrapper\Items()
            If Not first
              result + ", "
            EndIf
            first = #False
            ; Strings get quoted in list representation
            If *wrapper\Items()\VType = Jinja::#VT_String
              result + "'" + ToString(@*wrapper\Items()) + "'"
            Else
              result + ToString(@*wrapper\Items())
            EndIf
          Next
        EndIf
        result + "]"
        ProcedureReturn result

      Case Jinja::#VT_Map
        ProcedureReturn "{...}"

    EndSelect

    ProcedureReturn ""
  EndProcedure

  Procedure.d ToDouble(*v.JinjaVariant)
    If *v = #Null
      ProcedureReturn 0.0
    EndIf

    Select *v\VType
      Case Jinja::#VT_None
        ProcedureReturn 0.0
      Case Jinja::#VT_Boolean
        ProcedureReturn *v\IntVal * 1.0
      Case Jinja::#VT_Integer
        ProcedureReturn *v\IntVal * 1.0
      Case Jinja::#VT_Double
        ProcedureReturn *v\DblVal
      Case Jinja::#VT_String
        ProcedureReturn ValD(*v\StrVal)
      Default
        ProcedureReturn 0.0
    EndSelect
  EndProcedure

  Procedure.q ToInteger(*v.JinjaVariant)
    If *v = #Null
      ProcedureReturn 0
    EndIf

    Select *v\VType
      Case Jinja::#VT_None
        ProcedureReturn 0
      Case Jinja::#VT_Boolean
        ProcedureReturn *v\IntVal
      Case Jinja::#VT_Integer
        ProcedureReturn *v\IntVal
      Case Jinja::#VT_Double
        ProcedureReturn Int(*v\DblVal)
      Case Jinja::#VT_String
        ProcedureReturn Val(*v\StrVal)
      Default
        ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i IsTruthy(*v.JinjaVariant)
    ; Jinja truthiness: None is false, 0 is false, "" is false,
    ; empty list is false, False is false. Everything else is true.
    If *v = #Null
      ProcedureReturn #False
    EndIf

    Select *v\VType
      Case Jinja::#VT_None
        ProcedureReturn #False

      Case Jinja::#VT_Boolean
        ProcedureReturn Bool(*v\IntVal <> 0)

      Case Jinja::#VT_Integer
        ProcedureReturn Bool(*v\IntVal <> 0)

      Case Jinja::#VT_Double
        ProcedureReturn Bool(*v\DblVal <> 0.0)

      Case Jinja::#VT_String
        ProcedureReturn Bool(*v\StrVal <> "")

      Case Jinja::#VT_Markup
        ProcedureReturn Bool(*v\StrVal <> "")

      Case Jinja::#VT_List
        Protected *lw.VariantListWrapper = *v\ListPtr
        If *lw
          ProcedureReturn Bool(ListSize(*lw\Items()) > 0)
        EndIf
        ProcedureReturn #False

      Case Jinja::#VT_Map
        Protected *mw.VariantMapWrapper = *v\MapPtr
        If *mw
          ProcedureReturn Bool(MapSize(*mw\Entries()) > 0)
        EndIf
        ProcedureReturn #False

    EndSelect

    ProcedureReturn #False
  EndProcedure

  ; ===== Comparison =====

  Procedure.i VariantsEqual(*a.JinjaVariant, *b.JinjaVariant)
    ; Both null
    If *a\VType = Jinja::#VT_None And *b\VType = Jinja::#VT_None
      ProcedureReturn #True
    EndIf

    ; One null, one not
    If *a\VType = Jinja::#VT_None Or *b\VType = Jinja::#VT_None
      ProcedureReturn #False
    EndIf

    ; String comparison takes priority if either is string
    If *a\VType = Jinja::#VT_String Or *b\VType = Jinja::#VT_String Or *a\VType = Jinja::#VT_Markup Or *b\VType = Jinja::#VT_Markup
      ProcedureReturn Bool(ToString(*a) = ToString(*b))
    EndIf

    ; Boolean comparison
    If *a\VType = Jinja::#VT_Boolean And *b\VType = Jinja::#VT_Boolean
      ProcedureReturn Bool(*a\IntVal = *b\IntVal)
    EndIf

    ; Numeric comparison
    ProcedureReturn Bool(ToDouble(*a) = ToDouble(*b))
  EndProcedure

  Procedure.i CompareVariants(*a.JinjaVariant, *b.JinjaVariant)
    ; Returns: -1 if a < b, 0 if a == b, 1 if a > b
    ; Used for sorting and comparison operators
    Protected da.d = ToDouble(*a)
    Protected db.d = ToDouble(*b)

    If da < db
      ProcedureReturn -1
    ElseIf da > db
      ProcedureReturn 1
    Else
      ProcedureReturn 0
    EndIf
  EndProcedure

  ; ===== Memory Management =====

  Procedure CopyVariant(*dst.JinjaVariant, *src.JinjaVariant)
    ; Deep copy a variant
    If *src = #Null Or *dst = #Null
      ProcedureReturn
    EndIf

    *dst\VType = *src\VType
    *dst\IntVal = *src\IntVal
    *dst\DblVal = *src\DblVal
    *dst\StrVal = *src\StrVal
    *dst\ListPtr = #Null
    *dst\MapPtr = #Null

    ; Deep copy list
    If *src\VType = Jinja::#VT_List And *src\ListPtr
      Protected *srcList.VariantListWrapper = *src\ListPtr
      Protected *dstList.VariantListWrapper = AllocateStructure(VariantListWrapper)
      If *dstList
        ForEach *srcList\Items()
          AddElement(*dstList\Items())
          CopyVariant(@*dstList\Items(), @*srcList\Items())
        Next
        *dst\ListPtr = *dstList
      EndIf
    EndIf

    ; Deep copy map
    If *src\VType = Jinja::#VT_Map And *src\MapPtr
      Protected *srcMap.VariantMapWrapper = *src\MapPtr
      Protected *dstMap.VariantMapWrapper = AllocateStructure(VariantMapWrapper)
      If *dstMap
        ForEach *srcMap\Entries()
          *dstMap\Entries(MapKey(*srcMap\Entries())) = *srcMap\Entries()
          ; Deep copy nested structures
          If *srcMap\Entries()\VType = Jinja::#VT_List Or *srcMap\Entries()\VType = Jinja::#VT_Map
            CopyVariant(@*dstMap\Entries(), @*srcMap\Entries())
          EndIf
        Next
        *dst\MapPtr = *dstMap
      EndIf
    EndIf
  EndProcedure

  Procedure FreeVariant(*v.JinjaVariant)
    ; Free any allocated memory owned by this variant
    If *v = #Null
      ProcedureReturn
    EndIf

    If *v\VType = Jinja::#VT_List And *v\ListPtr
      FreeVariantList(*v\ListPtr)
      *v\ListPtr = #Null
    EndIf

    If *v\VType = Jinja::#VT_Map And *v\MapPtr
      FreeVariantMap(*v\MapPtr)
      *v\MapPtr = #Null
    EndIf

    *v\VType = Jinja::#VT_None
  EndProcedure

  Procedure FreeVariantList(*listPtr)
    If *listPtr = #Null
      ProcedureReturn
    EndIf

    Protected *wrapper.VariantListWrapper = *listPtr
    ForEach *wrapper\Items()
      FreeVariant(@*wrapper\Items())
    Next
    FreeStructure(*wrapper)
  EndProcedure

  Procedure FreeVariantMap(*mapPtr)
    If *mapPtr = #Null
      ProcedureReturn
    EndIf

    Protected *wrapper.VariantMapWrapper = *mapPtr
    ForEach *wrapper\Entries()
      FreeVariant(@*wrapper\Entries())
    Next
    FreeStructure(*wrapper)
  EndProcedure

  ; ===== List Operations =====

  Procedure.i VListSize(*v.JinjaVariant)
    If *v = #Null Or *v\VType <> Jinja::#VT_List Or *v\ListPtr = #Null
      ProcedureReturn 0
    EndIf
    Protected *wrapper.VariantListWrapper = *v\ListPtr
    ProcedureReturn ListSize(*wrapper\Items())
  EndProcedure

  Procedure.i VListGet(*v.JinjaVariant, index.i, *out.JinjaVariant)
    ; Get item at index from a list variant. Returns #True on success.
    If *v = #Null Or *v\VType <> Jinja::#VT_List Or *v\ListPtr = #Null
      NullVariant(*out)
      ProcedureReturn #False
    EndIf

    Protected *wrapper.VariantListWrapper = *v\ListPtr
    Protected count.i = ListSize(*wrapper\Items())

    If index < 0 Or index >= count
      NullVariant(*out)
      ProcedureReturn #False
    EndIf

    ; Navigate to the index
    SelectElement(*wrapper\Items(), index)
    CopyVariant(*out, @*wrapper\Items())
    ProcedureReturn #True
  EndProcedure

  Procedure VListAdd(*v.JinjaVariant, *item.JinjaVariant)
    ; Add an item to a list variant
    If *v = #Null Or *v\VType <> Jinja::#VT_List Or *v\ListPtr = #Null
      ProcedureReturn
    EndIf

    Protected *wrapper.VariantListWrapper = *v\ListPtr
    AddElement(*wrapper\Items())
    CopyVariant(@*wrapper\Items(), *item)
  EndProcedure

  ; ===== Map Operations =====

  Procedure.i VMapGet(*v.JinjaVariant, key.s, *out.JinjaVariant)
    ; Get value by key from a map variant. Returns #True if found.
    If *v = #Null Or *v\VType <> Jinja::#VT_Map Or *v\MapPtr = #Null
      NullVariant(*out)
      ProcedureReturn #False
    EndIf

    Protected *wrapper.VariantMapWrapper = *v\MapPtr
    If FindMapElement(*wrapper\Entries(), key)
      CopyVariant(*out, @*wrapper\Entries())
      ProcedureReturn #True
    EndIf

    NullVariant(*out)
    ProcedureReturn #False
  EndProcedure

  Procedure VMapSet(*v.JinjaVariant, key.s, *item.JinjaVariant)
    ; Set a key-value pair in a map variant
    If *v = #Null Or *v\VType <> Jinja::#VT_Map Or *v\MapPtr = #Null
      ProcedureReturn
    EndIf

    Protected *wrapper.VariantMapWrapper = *v\MapPtr
    ; Free existing value if replacing
    If FindMapElement(*wrapper\Entries(), key)
      FreeVariant(@*wrapper\Entries())
    EndIf
    *wrapper\Entries(key)\VType = Jinja::#VT_None
    CopyVariant(@*wrapper\Entries(key), *item)
  EndProcedure

  Procedure.i VMapHasKey(*v.JinjaVariant, key.s)
    If *v = #Null Or *v\VType <> Jinja::#VT_Map Or *v\MapPtr = #Null
      ProcedureReturn #False
    EndIf

    Protected *wrapper.VariantMapWrapper = *v\MapPtr
    ProcedureReturn Bool(FindMapElement(*wrapper\Entries(), key) <> 0)
  EndProcedure

  Procedure.i VMapSize(*v.JinjaVariant)
    If *v = #Null Or *v\VType <> Jinja::#VT_Map Or *v\MapPtr = #Null
      ProcedureReturn 0
    EndIf
    Protected *wrapper.VariantMapWrapper = *v\MapPtr
    ProcedureReturn MapSize(*wrapper\Entries())
  EndProcedure

  Procedure VMapKeys(*v.JinjaVariant, List keys.s())
    ; Fill the provided list with all keys of a map variant
    ClearList(keys())
    If *v = #Null Or *v\VType <> Jinja::#VT_Map Or *v\MapPtr = #Null
      ProcedureReturn
    EndIf
    Protected *wrapper.VariantMapWrapper = *v\MapPtr
    ForEach *wrapper\Entries()
      AddElement(keys())
      keys() = MapKey(*wrapper\Entries())
    Next
  EndProcedure

  ; ===== Type Name =====

  Procedure.s TypeName(vtype.i)
    Select vtype
      Case Jinja::#VT_None
        ProcedureReturn "Null"
      Case Jinja::#VT_Boolean
        ProcedureReturn "Boolean"
      Case Jinja::#VT_Integer
        ProcedureReturn "Integer"
      Case Jinja::#VT_Double
        ProcedureReturn "Double"
      Case Jinja::#VT_String
        ProcedureReturn "String"
      Case Jinja::#VT_List
        ProcedureReturn "List"
      Case Jinja::#VT_Map
        ProcedureReturn "Map"
      Case Jinja::#VT_Markup
        ProcedureReturn "Markup"
      Default
        ProcedureReturn "Unknown"
    EndSelect
  EndProcedure

EndModule
