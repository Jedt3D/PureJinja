; ============================================================================
; PureJinja - Context.pbi
; Variable scope stack for template rendering
; Scopes are pushed/popped for blocks, for loops, macros, etc.
; ============================================================================
EnableExplicit

DeclareModule JinjaContext

  ; --- Scope Level ---
  Structure ScopeLevel
    Map Variables.JinjaVariant::JinjaVariant()
  EndStructure

  ; --- Context Structure ---
  Structure JinjaContext
    List Scopes.ScopeLevel()    ; Last element = innermost scope
  EndStructure

  ; --- API ---
  Declare.i CreateContext()
  Declare FreeContext(*ctx.JinjaContext)
  Declare PushScope(*ctx.JinjaContext)
  Declare PopScope(*ctx.JinjaContext)
  Declare SetVariable(*ctx.JinjaContext, key.s, *value.JinjaVariant::JinjaVariant)
  Declare.i GetVariable(*ctx.JinjaContext, key.s, *out.JinjaVariant::JinjaVariant)
  Declare.i HasVariable(*ctx.JinjaContext, key.s)
  Declare SetGlobalVariable(*ctx.JinjaContext, key.s, *value.JinjaVariant::JinjaVariant)
  Declare.i ScopeDepth(*ctx.JinjaContext)

  ; --- Initialize context from a variable map ---
  Declare InitFromMap(*ctx.JinjaContext, Map variables.JinjaVariant::JinjaVariant())

EndDeclareModule

Module JinjaContext

  Procedure.i CreateContext()
    Protected *ctx.JinjaContext = AllocateStructure(JinjaContext)
    If *ctx
      ; Start with one global scope
      AddElement(*ctx\Scopes())
    EndIf
    ProcedureReturn *ctx
  EndProcedure

  Procedure FreeContext(*ctx.JinjaContext)
    If *ctx
      ; Free all variant values in all scopes
      ForEach *ctx\Scopes()
        ForEach *ctx\Scopes()\Variables()
          JinjaVariant::FreeVariant(@*ctx\Scopes()\Variables())
        Next
      Next
      FreeStructure(*ctx)
    EndIf
  EndProcedure

  Procedure PushScope(*ctx.JinjaContext)
    If *ctx
      ; Move to last element then add after it
      LastElement(*ctx\Scopes())
      AddElement(*ctx\Scopes())
    EndIf
  EndProcedure

  Procedure PopScope(*ctx.JinjaContext)
    If *ctx
      If ListSize(*ctx\Scopes()) > 1
        LastElement(*ctx\Scopes())
        ; Free variants in this scope
        ForEach *ctx\Scopes()\Variables()
          JinjaVariant::FreeVariant(@*ctx\Scopes()\Variables())
        Next
        DeleteElement(*ctx\Scopes())
      EndIf
    EndIf
  EndProcedure

  Procedure SetVariable(*ctx.JinjaContext, key.s, *value.JinjaVariant::JinjaVariant)
    ; Set in the current (innermost) scope
    If *ctx And *value
      LastElement(*ctx\Scopes())
      ; Free existing value if replacing
      If FindMapElement(*ctx\Scopes()\Variables(), key)
        JinjaVariant::FreeVariant(@*ctx\Scopes()\Variables())
      EndIf
      JinjaVariant::CopyVariant(@*ctx\Scopes()\Variables(key), *value)
    EndIf
  EndProcedure

  Procedure.i GetVariable(*ctx.JinjaContext, key.s, *out.JinjaVariant::JinjaVariant)
    ; Search from innermost to outermost scope. Returns #True if found.
    If *ctx
      ; Walk scopes from last to first
      LastElement(*ctx\Scopes())
      Repeat
        If FindMapElement(*ctx\Scopes()\Variables(), key)
          JinjaVariant::CopyVariant(*out, @*ctx\Scopes()\Variables())
          ProcedureReturn #True
        EndIf
      Until Not PreviousElement(*ctx\Scopes())
    EndIf

    JinjaVariant::NullVariant(*out)
    ProcedureReturn #False
  EndProcedure

  Procedure.i HasVariable(*ctx.JinjaContext, key.s)
    If *ctx
      LastElement(*ctx\Scopes())
      Repeat
        If FindMapElement(*ctx\Scopes()\Variables(), key)
          ProcedureReturn #True
        EndIf
      Until Not PreviousElement(*ctx\Scopes())
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure SetGlobalVariable(*ctx.JinjaContext, key.s, *value.JinjaVariant::JinjaVariant)
    ; Set in the outermost (global) scope
    If *ctx And *value
      FirstElement(*ctx\Scopes())
      If FindMapElement(*ctx\Scopes()\Variables(), key)
        JinjaVariant::FreeVariant(@*ctx\Scopes()\Variables())
      EndIf
      JinjaVariant::CopyVariant(@*ctx\Scopes()\Variables(key), *value)
    EndIf
  EndProcedure

  Procedure.i ScopeDepth(*ctx.JinjaContext)
    If *ctx
      ProcedureReturn ListSize(*ctx\Scopes())
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure InitFromMap(*ctx.JinjaContext, Map variables.JinjaVariant::JinjaVariant())
    ; Copy all variables from the map into the global scope
    If *ctx
      ForEach variables()
        SetGlobalVariable(*ctx, MapKey(variables()), @variables())
      Next
    EndIf
  EndProcedure

EndModule
