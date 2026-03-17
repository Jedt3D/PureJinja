; ============================================================================
; PureJinja - MarkupSafe.pbi
; HTML escaping utilities - prevents XSS by escaping special characters
; Markup-typed variants bypass auto-escaping (marked safe)
; ============================================================================
EnableExplicit

DeclareModule JinjaMarkup

  ; Escape HTML special characters: & < > " '
  Declare.s EscapeHTML(input.s)

  ; Check if a variant is already safe (Markup type)
  Declare.i IsMarkup(*v.JinjaVariant::JinjaVariant)

EndDeclareModule

Module JinjaMarkup

  Procedure.s EscapeHTML(input.s)
    Protected result.s = input
    ; Order matters: & must be first to avoid double-escaping
    result = ReplaceString(result, "&", "&amp;")
    result = ReplaceString(result, "<", "&lt;")
    result = ReplaceString(result, ">", "&gt;")
    result = ReplaceString(result, Chr(34), "&quot;")
    result = ReplaceString(result, "'", "&#39;")
    ProcedureReturn result
  EndProcedure

  Procedure.i IsMarkup(*v.JinjaVariant::JinjaVariant)
    If *v = #Null
      ProcedureReturn #False
    EndIf
    ProcedureReturn Bool(*v\VType = Jinja::#VT_Markup)
  EndProcedure

EndModule
