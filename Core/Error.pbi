; ============================================================================
; PureJinja - Error.pbi
; Global error state management (replaces exceptions)
; Pattern: SetError() -> check HasError() -> ClearError()
; ============================================================================
EnableExplicit

XIncludeFile "Constants.pbi"

DeclareModule JinjaError

  ; --- Error State Structure ---
  Structure JinjaErrorState
    HasError.i           ; #True if an error is active
    Code.i               ; ErrorCode enumeration value
    Message.s            ; Human-readable error message
    LineNumber.i         ; Template line number where error occurred
    TemplateName.s       ; Name of the template (if known)
  EndStructure

  ; --- Public API ---
  Declare SetError(code.i, message.s, lineNumber.i = 0, templateName.s = "")
  Declare.i HasError()
  Declare ClearError()
  Declare.s GetErrorMessage()
  Declare.i GetErrorCode()
  Declare.i GetErrorLine()
  Declare.s GetErrorTemplate()
  Declare.s FormatError()

EndDeclareModule

Module JinjaError

  ; --- Global Error State ---
  Global gError.JinjaErrorState

  Procedure SetError(code.i, message.s, lineNumber.i = 0, templateName.s = "")
    ; Only set if no error is already active (first error wins)
    If Not gError\HasError
      gError\HasError = #True
      gError\Code = code
      gError\Message = message
      gError\LineNumber = lineNumber
      gError\TemplateName = templateName
    EndIf
  EndProcedure

  Procedure.i HasError()
    ProcedureReturn gError\HasError
  EndProcedure

  Procedure ClearError()
    gError\HasError = #False
    gError\Code = Jinja::#ERR_None
    gError\Message = ""
    gError\LineNumber = 0
    gError\TemplateName = ""
  EndProcedure

  Procedure.s GetErrorMessage()
    ProcedureReturn gError\Message
  EndProcedure

  Procedure.i GetErrorCode()
    ProcedureReturn gError\Code
  EndProcedure

  Procedure.i GetErrorLine()
    ProcedureReturn gError\LineNumber
  EndProcedure

  Procedure.s GetErrorTemplate()
    ProcedureReturn gError\TemplateName
  EndProcedure

  Procedure.s FormatError()
    ; Format a human-readable error string
    Protected result.s = ""

    Select gError\Code
      Case Jinja::#ERR_Syntax
        result = "SyntaxError"
      Case Jinja::#ERR_Render
        result = "RenderError"
      Case Jinja::#ERR_Undefined
        result = "UndefinedError"
      Case Jinja::#ERR_Type
        result = "TypeError"
      Case Jinja::#ERR_Filter
        result = "FilterError"
      Case Jinja::#ERR_Loader
        result = "LoaderError"
      Case Jinja::#ERR_Inheritance
        result = "InheritanceError"
      Default
        result = "Error"
    EndSelect

    result + ": " + gError\Message

    If gError\TemplateName <> ""
      result + " (in " + gError\TemplateName + ")"
    EndIf

    If gError\LineNumber > 0
      result + " at line " + Str(gError\LineNumber)
    EndIf

    ProcedureReturn result
  EndProcedure

EndModule
