; ============================================================================
; PureJinja - Renderer.pbi
; Tree-walking renderer and expression evaluator
; Traverses the AST and produces output string
; ============================================================================
EnableExplicit

DeclareModule JinjaRenderer

  ; --- Main Render Entry Point ---
  ; Renders a template AST with the given environment and variables
  Declare.s Render(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode, Map variables.JinjaVariant::JinjaVariant())

  ; --- Render with existing context (for include) ---
  Declare.s RenderWithContext(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode, *ctx.JinjaContext::JinjaContext)

EndDeclareModule

Module JinjaRenderer

  ; --- Forward Declarations ---
  Declare.s RenderNode(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
  Declare EvaluateExpression(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)

  ; --- Global state for joiner() and cycler() callables ---
  ; Joiner: maps unique string ID -> "1" (first call pending) or "0" (already called)
  Global NewMap gJoinerState.s()
  Global gJoinerCounter.i = 0
  ; Cycler: maps unique string ID -> current index (integer)
  Global NewMap gCyclerIndex.i()
  Global gCyclerCounter.i = 0

  ; --- Global state for recursive for loop ---
  ; Stores the current recursive for node, env, and ctx so loop() can re-invoke the body
  Global *gRecursiveForNode.JinjaAST::ASTNode = #Null
  Global *gRecursiveForEnv.JinjaEnv::JinjaEnvironment = #Null
  Global *gRecursiveForCtx.JinjaContext::JinjaContext = #Null

  ; Forward declare the helper for rendering a for-body with a given iterable
  Declare.s RenderForItems(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *iterV.JinjaVariant::JinjaVariant)

  ; ===== Render Helpers =====

  Procedure.s RenderNodeList(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ; Render a linked list of nodes (following ->Next)
    Protected output.s = ""
    Protected *current.JinjaAST::ASTNode = *node
    While *current
      If JinjaError::HasError()
        Break
      EndIf
      output + RenderNode(*env, *ctx, *current)
      *current = *current\Next
    Wend
    ProcedureReturn output
  EndProcedure

  Procedure.s AutoEscape(*env.JinjaEnv::JinjaEnvironment, *value.JinjaVariant::JinjaVariant)
    ; Apply auto-escaping based on environment settings
    If *value\VType = Jinja::#VT_Null
      ProcedureReturn ""
    EndIf

    ; Markup values are already safe
    If *value\VType = Jinja::#VT_Markup
      ProcedureReturn *value\StrVal
    EndIf

    Protected s.s = JinjaVariant::ToString(*value)

    If *env\Autoescape
      ProcedureReturn JinjaMarkup::EscapeHTML(s)
    EndIf

    ProcedureReturn s
  EndProcedure

  ; ===== Expression Evaluation =====

  Procedure EvaluateBinaryOp(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    Protected leftV.JinjaVariant::JinjaVariant
    Protected rightV.JinjaVariant::JinjaVariant

    EvaluateExpression(*env, *ctx, *node\Left, @leftV)
    If JinjaError::HasError() : JinjaVariant::NullVariant(*result) : ProcedureReturn : EndIf

    ; Short-circuit for and/or
    Protected op.s = *node\StringVal
    If op = "and"
      If Not JinjaVariant::IsTruthy(@leftV)
        JinjaVariant::CopyVariant(*result, @leftV)
        JinjaVariant::FreeVariant(@leftV)
        ProcedureReturn
      EndIf
      EvaluateExpression(*env, *ctx, *node\Right, @rightV)
      JinjaVariant::CopyVariant(*result, @rightV)
      JinjaVariant::FreeVariant(@leftV)
      JinjaVariant::FreeVariant(@rightV)
      ProcedureReturn
    EndIf

    If op = "or"
      If JinjaVariant::IsTruthy(@leftV)
        JinjaVariant::CopyVariant(*result, @leftV)
        JinjaVariant::FreeVariant(@leftV)
        ProcedureReturn
      EndIf
      EvaluateExpression(*env, *ctx, *node\Right, @rightV)
      JinjaVariant::CopyVariant(*result, @rightV)
      JinjaVariant::FreeVariant(@leftV)
      JinjaVariant::FreeVariant(@rightV)
      ProcedureReturn
    EndIf

    EvaluateExpression(*env, *ctx, *node\Right, @rightV)
    If JinjaError::HasError()
      JinjaVariant::FreeVariant(@leftV)
      JinjaVariant::NullVariant(*result)
      ProcedureReturn
    EndIf

    Select op
      Case "+"
        ; String concatenation if either is string, otherwise numeric add
        If leftV\VType = Jinja::#VT_String Or rightV\VType = Jinja::#VT_String
          JinjaVariant::StrVariant(*result, JinjaVariant::ToString(@leftV) + JinjaVariant::ToString(@rightV))
        ElseIf leftV\VType = Jinja::#VT_Integer And rightV\VType = Jinja::#VT_Integer
          JinjaVariant::IntVariant(*result, leftV\IntVal + rightV\IntVal)
        Else
          JinjaVariant::DblVariant(*result, JinjaVariant::ToDouble(@leftV) + JinjaVariant::ToDouble(@rightV))
        EndIf

      Case "-"
        If leftV\VType = Jinja::#VT_Integer And rightV\VType = Jinja::#VT_Integer
          JinjaVariant::IntVariant(*result, leftV\IntVal - rightV\IntVal)
        Else
          JinjaVariant::DblVariant(*result, JinjaVariant::ToDouble(@leftV) - JinjaVariant::ToDouble(@rightV))
        EndIf

      Case "*"
        If leftV\VType = Jinja::#VT_Integer And rightV\VType = Jinja::#VT_Integer
          JinjaVariant::IntVariant(*result, leftV\IntVal * rightV\IntVal)
        Else
          JinjaVariant::DblVariant(*result, JinjaVariant::ToDouble(@leftV) * JinjaVariant::ToDouble(@rightV))
        EndIf

      Case "/"
        Protected divisor.d = JinjaVariant::ToDouble(@rightV)
        If divisor = 0
          JinjaVariant::IntVariant(*result, 0)
        Else
          JinjaVariant::DblVariant(*result, JinjaVariant::ToDouble(@leftV) / divisor)
        EndIf

      Case "//"
        Protected fdivisor.d = JinjaVariant::ToDouble(@rightV)
        If fdivisor = 0
          JinjaVariant::IntVariant(*result, 0)
        Else
          JinjaVariant::IntVariant(*result, Int(JinjaVariant::ToDouble(@leftV) / fdivisor))
        EndIf

      Case "%"
        Protected mdivisor.d = JinjaVariant::ToDouble(@rightV)
        If mdivisor = 0
          JinjaVariant::IntVariant(*result, 0)
        Else
          JinjaVariant::DblVariant(*result, Mod(JinjaVariant::ToDouble(@leftV), mdivisor))
        EndIf

      Case "**"
        JinjaVariant::DblVariant(*result, Pow(JinjaVariant::ToDouble(@leftV), JinjaVariant::ToDouble(@rightV)))

      Case "~"
        ; String concatenation
        JinjaVariant::StrVariant(*result, JinjaVariant::ToString(@leftV) + JinjaVariant::ToString(@rightV))

      Default
        JinjaVariant::NullVariant(*result)
    EndSelect

    JinjaVariant::FreeVariant(@leftV)
    JinjaVariant::FreeVariant(@rightV)
  EndProcedure

  Procedure EvaluateUnaryOp(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    Protected operandV.JinjaVariant::JinjaVariant
    EvaluateExpression(*env, *ctx, *node\Left, @operandV)
    If JinjaError::HasError() : JinjaVariant::NullVariant(*result) : ProcedureReturn : EndIf

    Select *node\StringVal
      Case "not"
        JinjaVariant::BoolVariant(*result, Bool(Not JinjaVariant::IsTruthy(@operandV)))
      Case "-"
        If operandV\VType = Jinja::#VT_Integer
          JinjaVariant::IntVariant(*result, -operandV\IntVal)
        Else
          JinjaVariant::DblVariant(*result, -JinjaVariant::ToDouble(@operandV))
        EndIf
      Case "+"
        JinjaVariant::CopyVariant(*result, @operandV)
      Default
        JinjaVariant::NullVariant(*result)
    EndSelect

    JinjaVariant::FreeVariant(@operandV)
  EndProcedure

  Procedure EvaluateCompare(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    Protected leftV.JinjaVariant::JinjaVariant
    Protected rightV.JinjaVariant::JinjaVariant

    EvaluateExpression(*env, *ctx, *node\Left, @leftV)
    If JinjaError::HasError() : JinjaVariant::NullVariant(*result) : ProcedureReturn : EndIf

    EvaluateExpression(*env, *ctx, *node\Right, @rightV)
    If JinjaError::HasError()
      JinjaVariant::FreeVariant(@leftV)
      JinjaVariant::NullVariant(*result)
      ProcedureReturn
    EndIf

    Protected op.s = *node\StringVal

    Select op
      Case "=="
        JinjaVariant::BoolVariant(*result, JinjaVariant::VariantsEqual(@leftV, @rightV))

      Case "!="
        JinjaVariant::BoolVariant(*result, Bool(Not JinjaVariant::VariantsEqual(@leftV, @rightV)))

      Case "<"
        JinjaVariant::BoolVariant(*result, Bool(JinjaVariant::ToDouble(@leftV) < JinjaVariant::ToDouble(@rightV)))

      Case ">"
        JinjaVariant::BoolVariant(*result, Bool(JinjaVariant::ToDouble(@leftV) > JinjaVariant::ToDouble(@rightV)))

      Case "<="
        JinjaVariant::BoolVariant(*result, Bool(JinjaVariant::ToDouble(@leftV) <= JinjaVariant::ToDouble(@rightV)))

      Case ">="
        JinjaVariant::BoolVariant(*result, Bool(JinjaVariant::ToDouble(@leftV) >= JinjaVariant::ToDouble(@rightV)))

      Case "in"
        ; Check if left is in right (string contains or list contains)
        Protected found.i = #False
        If rightV\VType = Jinja::#VT_String Or rightV\VType = Jinja::#VT_Markup
          ; String contains
          found = Bool(FindString(JinjaVariant::ToString(@rightV), JinjaVariant::ToString(@leftV)) > 0)
        ElseIf rightV\VType = Jinja::#VT_List
          ; List contains
          Protected count.i = JinjaVariant::VListSize(@rightV)
          Protected i.i
          Protected itemV.JinjaVariant::JinjaVariant
          For i = 0 To count - 1
            JinjaVariant::VListGet(@rightV, i, @itemV)
            If JinjaVariant::VariantsEqual(@leftV, @itemV)
              found = #True
              JinjaVariant::FreeVariant(@itemV)
              Break
            EndIf
            JinjaVariant::FreeVariant(@itemV)
          Next
        EndIf
        JinjaVariant::BoolVariant(*result, found)

      Case "not in"
        Protected notFound.i = #True
        If rightV\VType = Jinja::#VT_String Or rightV\VType = Jinja::#VT_Markup
          notFound = Bool(FindString(JinjaVariant::ToString(@rightV), JinjaVariant::ToString(@leftV)) = 0)
        ElseIf rightV\VType = Jinja::#VT_List
          Protected ncount.i = JinjaVariant::VListSize(@rightV)
          Protected ni.i
          Protected nitemV.JinjaVariant::JinjaVariant
          For ni = 0 To ncount - 1
            JinjaVariant::VListGet(@rightV, ni, @nitemV)
            If JinjaVariant::VariantsEqual(@leftV, @nitemV)
              notFound = #False
              JinjaVariant::FreeVariant(@nitemV)
              Break
            EndIf
            JinjaVariant::FreeVariant(@nitemV)
          Next
        EndIf
        JinjaVariant::BoolVariant(*result, notFound)

      Case "is"
        ; Test operator - check identity/type tests
        ; Right side should be a test name (variable node with name like "none", "defined", etc.)
        Protected testName.s = ""
        If *node\Right And *node\Right\NodeType = Jinja::#NODE_Variable
          testName = *node\Right\StringVal
        ElseIf *node\Right And *node\Right\NodeType = Jinja::#NODE_Literal And *node\Right\IntVal = Jinja::#LIT_None
          testName = "none"
        EndIf

        Select LCase(testName)
          Case "none"
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType = Jinja::#VT_Null))
          Case "defined"
            ; A variable is defined if it's not null (was found in context)
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType <> Jinja::#VT_Null))
          Case "undefined"
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType = Jinja::#VT_Null))
          Case "even"
            JinjaVariant::BoolVariant(*result, Bool(JinjaVariant::ToInteger(@leftV) % 2 = 0))
          Case "odd"
            JinjaVariant::BoolVariant(*result, Bool(JinjaVariant::ToInteger(@leftV) % 2 <> 0))
          Case "number"
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType = Jinja::#VT_Integer Or leftV\VType = Jinja::#VT_Double))
          Case "string"
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType = Jinja::#VT_String Or leftV\VType = Jinja::#VT_Markup))
          Default
            JinjaVariant::BoolVariant(*result, #False)
        EndSelect

      Case "is not"
        Protected testName2.s = ""
        If *node\Right And *node\Right\NodeType = Jinja::#NODE_Variable
          testName2 = *node\Right\StringVal
        ElseIf *node\Right And *node\Right\NodeType = Jinja::#NODE_Literal And *node\Right\IntVal = Jinja::#LIT_None
          testName2 = "none"
        EndIf

        Select LCase(testName2)
          Case "none"
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType <> Jinja::#VT_Null))
          Case "defined"
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType = Jinja::#VT_Null))
          Case "undefined"
            JinjaVariant::BoolVariant(*result, Bool(leftV\VType <> Jinja::#VT_Null))
          Default
            JinjaVariant::BoolVariant(*result, #True)
        EndSelect

      Default
        JinjaVariant::BoolVariant(*result, #False)
    EndSelect

    JinjaVariant::FreeVariant(@leftV)
    JinjaVariant::FreeVariant(@rightV)
  EndProcedure

  Procedure EvaluateGetAttr(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    Protected objV.JinjaVariant::JinjaVariant
    EvaluateExpression(*env, *ctx, *node\Left, @objV)
    If JinjaError::HasError() : JinjaVariant::NullVariant(*result) : ProcedureReturn : EndIf

    If objV\VType = Jinja::#VT_Map
      JinjaVariant::VMapGet(@objV, *node\StringVal, *result)
    Else
      JinjaVariant::NullVariant(*result)
    EndIf

    JinjaVariant::FreeVariant(@objV)
  EndProcedure

  Procedure EvaluateGetItem(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    Protected objV.JinjaVariant::JinjaVariant
    Protected idxV.JinjaVariant::JinjaVariant

    EvaluateExpression(*env, *ctx, *node\Left, @objV)
    If JinjaError::HasError() : JinjaVariant::NullVariant(*result) : ProcedureReturn : EndIf

    EvaluateExpression(*env, *ctx, *node\Right, @idxV)
    If JinjaError::HasError()
      JinjaVariant::FreeVariant(@objV)
      JinjaVariant::NullVariant(*result)
      ProcedureReturn
    EndIf

    If objV\VType = Jinja::#VT_Map
      JinjaVariant::VMapGet(@objV, JinjaVariant::ToString(@idxV), *result)
    ElseIf objV\VType = Jinja::#VT_List
      JinjaVariant::VListGet(@objV, JinjaVariant::ToInteger(@idxV), *result)
    Else
      JinjaVariant::NullVariant(*result)
    EndIf

    JinjaVariant::FreeVariant(@objV)
    JinjaVariant::FreeVariant(@idxV)
  EndProcedure

  Procedure EvaluateFilter(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    ; Evaluate the expression being filtered
    Protected valueV.JinjaVariant::JinjaVariant
    EvaluateExpression(*env, *ctx, *node\Left, @valueV)
    If JinjaError::HasError() : JinjaVariant::NullVariant(*result) : ProcedureReturn : EndIf

    ; Look up filter
    Protected filterAddr.i = JinjaEnv::GetFilter(*env, *node\StringVal)
    If filterAddr = #Null
      ; Unknown filter - return value unchanged
      JinjaVariant::CopyVariant(*result, @valueV)
      JinjaVariant::FreeVariant(@valueV)
      ProcedureReturn
    EndIf

    ; Evaluate filter arguments
    Protected argCount.i = 0
    Protected *argNode.JinjaAST::ASTNode = *node\Args
    While *argNode
      argCount + 1
      *argNode = *argNode\Next
    Wend

    ; Allocate args array
    Protected *argsArray.JinjaVariant::JinjaVariant = #Null
    If argCount > 0
      *argsArray = AllocateMemory(argCount * SizeOf(JinjaVariant::JinjaVariant))
      If *argsArray
        Protected ai.i = 0
        *argNode = *node\Args
        While *argNode
          Protected *argSlot.JinjaVariant::JinjaVariant = *argsArray + (ai * SizeOf(JinjaVariant::JinjaVariant))
          EvaluateExpression(*env, *ctx, *argNode, *argSlot)
          ai + 1
          *argNode = *argNode\Next
        Wend
      EndIf
    EndIf

    ; Call filter
    Protected filterProc.JinjaEnv::ProtoFilter = filterAddr
    filterProc(@valueV, *argsArray, argCount, *result)

    ; Cleanup
    If *argsArray
      Protected fi.i
      For fi = 0 To argCount - 1
        Protected *freeSlot.JinjaVariant::JinjaVariant = *argsArray + (fi * SizeOf(JinjaVariant::JinjaVariant))
        JinjaVariant::FreeVariant(*freeSlot)
      Next
      FreeMemory(*argsArray)
    EndIf
    JinjaVariant::FreeVariant(@valueV)
  EndProcedure

  Procedure EvaluateListLiteral(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::NewListVariant(*result)

    Protected *argNode.JinjaAST::ASTNode = *node\Args
    While *argNode
      Protected itemV.JinjaVariant::JinjaVariant
      EvaluateExpression(*env, *ctx, *argNode, @itemV)
      If JinjaError::HasError()
        JinjaVariant::FreeVariant(@itemV)
        ProcedureReturn
      EndIf
      JinjaVariant::VListAdd(*result, @itemV)
      JinjaVariant::FreeVariant(@itemV)
      *argNode = *argNode\Next
    Wend
  EndProcedure

  Procedure EvaluateDictLiteral(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    JinjaVariant::NewMapVariant(*result)
    Protected *argNode.JinjaAST::ASTNode = *node\Args
    While *argNode
      Protected keyV.JinjaVariant::JinjaVariant
      EvaluateExpression(*env, *ctx, *argNode, @keyV)
      Protected keyStr.s = JinjaVariant::ToString(@keyV)
      JinjaVariant::FreeVariant(@keyV)
      *argNode = *argNode\Next
      If *argNode = #Null : ProcedureReturn : EndIf
      Protected valV.JinjaVariant::JinjaVariant
      EvaluateExpression(*env, *ctx, *argNode, @valV)
      JinjaVariant::VMapSet(*result, keyStr, @valV)
      JinjaVariant::FreeVariant(@valV)
      *argNode = *argNode\Next
    Wend
  EndProcedure

  Procedure EvaluateCall(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    Protected funcName.s = *node\StringVal

    ; Check if it's a macro call
    If FindMapElement(*env\MacroDefs(), funcName)
      Protected *macroNode.JinjaAST::ASTNode = *env\MacroDefs(funcName)
      If *macroNode

        ; Push new scope for macro
        JinjaContext::PushScope(*ctx)

        ; Bind arguments to parameters
        Protected params.s = *macroNode\StringVal2  ; comma-separated param names
        Protected *argNode.JinjaAST::ASTNode = *node\Args
        Protected paramIdx.i = 0

        While *argNode
          ; Extract param name by index from CSV
          Protected paramName.s = ""
          Protected pCount.i = CountString(params, ",") + 1
          If paramIdx < pCount
            paramName = StringField(params, paramIdx + 1, ",")
          EndIf

          If paramName <> ""
            Protected argV.JinjaVariant::JinjaVariant
            EvaluateExpression(*env, *ctx, *argNode, @argV)
            JinjaContext::SetVariable(*ctx, Trim(paramName), @argV)
            JinjaVariant::FreeVariant(@argV)
          EndIf

          paramIdx + 1
          *argNode = *argNode\Next
        Wend

        ; Render macro body
        Protected macroOutput.s = RenderNodeList(*env, *ctx, *macroNode\Body)

        ; Pop macro scope
        JinjaContext::PopScope(*ctx)

        JinjaVariant::StrVariant(*result, macroOutput)
        ProcedureReturn
      EndIf
    EndIf

    ; Built-in functions
    Select LCase(funcName)
      Case "loop"
        ; loop(newItems) — re-render the recursive for body with a new iterable.
        ; Only works inside a {% for ... recursive %} loop.
        If *gRecursiveForNode <> #Null And *node\Args <> #Null
          Protected loopArgV.JinjaVariant::JinjaVariant
          EvaluateExpression(*gRecursiveForEnv, *ctx, *node\Args, @loopArgV)
          If Not JinjaError::HasError()
            If loopArgV\VType = Jinja::#VT_List And JinjaVariant::VListSize(@loopArgV) > 0
              Protected loopOutput.s = RenderForItems(*gRecursiveForEnv, *ctx, *gRecursiveForNode, @loopArgV)
              JinjaVariant::MarkupVariant(*result, loopOutput)
            Else
              JinjaVariant::StrVariant(*result, "")
            EndIf
          Else
            JinjaVariant::StrVariant(*result, "")
          EndIf
          JinjaVariant::FreeVariant(@loopArgV)
        Else
          JinjaVariant::StrVariant(*result, "")
        EndIf

      Case "namespace"
        ; namespace() creates a mutable map that persists across scopes.
        ; Arguments are ignored in this implementation (empty namespace).
        JinjaVariant::NewMapVariant(*result)

      Case "range"
        ; range(stop) or range(start, stop) or range(start, stop, step)
        Protected rangeStart.i = 0
        Protected rangeStop.i = 0
        Protected rangeStep.i = 1

        ; Count args
        Protected rArgCount.i = 0
        Protected *rArg.JinjaAST::ASTNode = *node\Args
        While *rArg
          rArgCount + 1
          *rArg = *rArg\Next
        Wend

        Protected rV1.JinjaVariant::JinjaVariant
        Protected rV2.JinjaVariant::JinjaVariant
        Protected rV3.JinjaVariant::JinjaVariant

        If rArgCount = 1
          EvaluateExpression(*env, *ctx, *node\Args, @rV1)
          rangeStop = JinjaVariant::ToInteger(@rV1)
          JinjaVariant::FreeVariant(@rV1)
        ElseIf rArgCount >= 2
          EvaluateExpression(*env, *ctx, *node\Args, @rV1)
          rangeStart = JinjaVariant::ToInteger(@rV1)
          JinjaVariant::FreeVariant(@rV1)
          EvaluateExpression(*env, *ctx, *node\Args\Next, @rV2)
          rangeStop = JinjaVariant::ToInteger(@rV2)
          JinjaVariant::FreeVariant(@rV2)
        EndIf
        If rArgCount >= 3
          EvaluateExpression(*env, *ctx, *node\Args\Next\Next, @rV3)
          rangeStep = JinjaVariant::ToInteger(@rV3)
          JinjaVariant::FreeVariant(@rV3)
          If rangeStep = 0 : rangeStep = 1 : EndIf
        EndIf

        JinjaVariant::NewListVariant(*result)
        Protected ri.i
        Protected riV.JinjaVariant::JinjaVariant
        If rangeStep > 0
          ri = rangeStart
          While ri < rangeStop
            JinjaVariant::IntVariant(@riV, ri)
            JinjaVariant::VListAdd(*result, @riV)
            ri + rangeStep
          Wend
        ElseIf rangeStep < 0
          ri = rangeStart
          While ri > rangeStop
            JinjaVariant::IntVariant(@riV, ri)
            JinjaVariant::VListAdd(*result, @riV)
            ri + rangeStep
          Wend
        EndIf

      Case "dict"
        ; dict() with no args creates an empty dictionary.
        ; (Keyword-argument form is not supported; use dict literals {"k": v} instead.)
        JinjaVariant::NewMapVariant(*result)

      Case "joiner"
        ; joiner(sep=", ") — returns a callable separator object.
        ; First call returns ""; subsequent calls return sep.
        ; Usage: {% set j = joiner(", ") %}{% for x in items %}{{ j() }}{{ x }}{% endfor %}
        Protected joinerSep.s = ", "
        If *node\Args
          Protected joinerSepV.JinjaVariant::JinjaVariant
          EvaluateExpression(*env, *ctx, *node\Args, @joinerSepV)
          joinerSep = JinjaVariant::ToString(@joinerSepV)
          JinjaVariant::FreeVariant(@joinerSepV)
        EndIf
        ; Generate a unique ID for this joiner instance
        gJoinerCounter + 1
        Protected joinerId.s = "__joiner__" + Str(gJoinerCounter)
        ; Register state: "1" means "first call not yet made"
        gJoinerState(joinerId) = "1"
        ; Build the joiner map variant (holds ID and sep so EvaluateCall can find them)
        JinjaVariant::NewMapVariant(*result)
        Protected joinerIdV.JinjaVariant::JinjaVariant
        Protected joinerSepV2.JinjaVariant::JinjaVariant
        JinjaVariant::StrVariant(@joinerIdV, joinerId)
        JinjaVariant::VMapSet(*result, "_joiner_id", @joinerIdV)
        JinjaVariant::FreeVariant(@joinerIdV)
        JinjaVariant::StrVariant(@joinerSepV2, joinerSep)
        JinjaVariant::VMapSet(*result, "_joiner_sep", @joinerSepV2)
        JinjaVariant::FreeVariant(@joinerSepV2)

      Case "cycler"
        ; cycler(item1, item2, ...) — returns a callable that cycles through items.
        ; Usage: {% set c = cycler("odd", "even") %}{{ c() }}{{ c() }}
        ; Generate a unique ID for this cycler instance
        gCyclerCounter + 1
        Protected cyclerId.s = "__cycler__" + Str(gCyclerCounter)
        gCyclerIndex(cyclerId) = 0
        ; Build cycler map variant with ID and items (as a list)
        JinjaVariant::NewMapVariant(*result)
        Protected cyclerIdV.JinjaVariant::JinjaVariant
        JinjaVariant::StrVariant(@cyclerIdV, cyclerId)
        JinjaVariant::VMapSet(*result, "_cycler_id", @cyclerIdV)
        JinjaVariant::FreeVariant(@cyclerIdV)
        ; Store items as a list in the map
        Protected cyclerItemsV.JinjaVariant::JinjaVariant
        JinjaVariant::NewListVariant(@cyclerItemsV)
        Protected *cArg.JinjaAST::ASTNode = *node\Args
        While *cArg
          Protected cItemV.JinjaVariant::JinjaVariant
          EvaluateExpression(*env, *ctx, *cArg, @cItemV)
          JinjaVariant::VListAdd(@cyclerItemsV, @cItemV)
          JinjaVariant::FreeVariant(@cItemV)
          *cArg = *cArg\Next
        Wend
        JinjaVariant::VMapSet(*result, "_cycler_items", @cyclerItemsV)
        JinjaVariant::FreeVariant(@cyclerItemsV)

      Default
        ; Not a built-in function — check if funcName is a callable variable
        ; (joiner or cycler object stored in context)
        Protected callableV.JinjaVariant::JinjaVariant
        JinjaContext::GetVariable(*ctx, funcName, @callableV)
        If callableV\VType = Jinja::#VT_Map
          ; Check for joiner: map has "_joiner_id" key
          Protected joinerIdKeyV.JinjaVariant::JinjaVariant
          If JinjaVariant::VMapGet(@callableV, "_joiner_id", @joinerIdKeyV)
            Protected joinerIdKey.s = JinjaVariant::ToString(@joinerIdKeyV)
            JinjaVariant::FreeVariant(@joinerIdKeyV)
            If FindMapElement(gJoinerState(), joinerIdKey)
              If gJoinerState() = "1"
                ; First call: return empty string, flip state
                gJoinerState() = "0"
                JinjaVariant::StrVariant(*result, "")
              Else
                ; Subsequent calls: return the separator
                Protected joinerSepKeyV.JinjaVariant::JinjaVariant
                JinjaVariant::VMapGet(@callableV, "_joiner_sep", @joinerSepKeyV)
                JinjaVariant::CopyVariant(*result, @joinerSepKeyV)
                JinjaVariant::FreeVariant(@joinerSepKeyV)
              EndIf
            Else
              JinjaVariant::StrVariant(*result, "")
            EndIf
            JinjaVariant::FreeVariant(@callableV)
            ProcedureReturn
          EndIf
          JinjaVariant::FreeVariant(@joinerIdKeyV)

          ; Check for cycler: map has "_cycler_id" key
          Protected cyclerIdKeyV.JinjaVariant::JinjaVariant
          If JinjaVariant::VMapGet(@callableV, "_cycler_id", @cyclerIdKeyV)
            Protected cyclerIdKey.s = JinjaVariant::ToString(@cyclerIdKeyV)
            JinjaVariant::FreeVariant(@cyclerIdKeyV)
            If FindMapElement(gCyclerIndex(), cyclerIdKey)
              Protected curIdx.i = gCyclerIndex()
              ; Get the items list from the map
              Protected cyclerItemsKeyV.JinjaVariant::JinjaVariant
              JinjaVariant::VMapGet(@callableV, "_cycler_items", @cyclerItemsKeyV)
              Protected cyclerCount.i = JinjaVariant::VListSize(@cyclerItemsKeyV)
              If cyclerCount > 0
                Protected cyclerItemOut.JinjaVariant::JinjaVariant
                JinjaVariant::VListGet(@cyclerItemsKeyV, curIdx % cyclerCount, @cyclerItemOut)
                JinjaVariant::CopyVariant(*result, @cyclerItemOut)
                JinjaVariant::FreeVariant(@cyclerItemOut)
                ; Advance the index
                gCyclerIndex() = (curIdx + 1) % cyclerCount
              Else
                JinjaVariant::StrVariant(*result, "")
              EndIf
              JinjaVariant::FreeVariant(@cyclerItemsKeyV)
            Else
              JinjaVariant::StrVariant(*result, "")
            EndIf
            JinjaVariant::FreeVariant(@callableV)
            ProcedureReturn
          EndIf
          JinjaVariant::FreeVariant(@cyclerIdKeyV)
        EndIf
        JinjaVariant::FreeVariant(@callableV)
        ; Unknown function - return null
        JinjaVariant::NullVariant(*result)
    EndSelect
  EndProcedure

  ; ===== Main Expression Evaluator =====

  Procedure EvaluateExpression(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *result.JinjaVariant::JinjaVariant)
    If *node = #Null
      JinjaVariant::NullVariant(*result)
      ProcedureReturn
    EndIf

    Select *node\NodeType
      Case Jinja::#NODE_Literal
        ; Create variant based on literal subtype
        Select *node\IntVal  ; IntVal holds the LiteralType
          Case Jinja::#LIT_String
            JinjaVariant::StrVariant(*result, *node\StringVal)
          Case Jinja::#LIT_Integer
            JinjaVariant::IntVariant(*result, Int(*node\DblVal))
          Case Jinja::#LIT_Float
            JinjaVariant::DblVariant(*result, *node\DblVal)
          Case Jinja::#LIT_Boolean
            JinjaVariant::BoolVariant(*result, Bool(*node\DblVal <> 0))
          Case Jinja::#LIT_None
            JinjaVariant::NullVariant(*result)
          Default
            JinjaVariant::NullVariant(*result)
        EndSelect

      Case Jinja::#NODE_Variable
        JinjaContext::GetVariable(*ctx, *node\StringVal, *result)

      Case Jinja::#NODE_BinaryOp
        EvaluateBinaryOp(*env, *ctx, *node, *result)

      Case Jinja::#NODE_UnaryOp
        EvaluateUnaryOp(*env, *ctx, *node, *result)

      Case Jinja::#NODE_Compare
        EvaluateCompare(*env, *ctx, *node, *result)

      Case Jinja::#NODE_GetAttr
        EvaluateGetAttr(*env, *ctx, *node, *result)

      Case Jinja::#NODE_GetItem
        EvaluateGetItem(*env, *ctx, *node, *result)

      Case Jinja::#NODE_Filter
        EvaluateFilter(*env, *ctx, *node, *result)

      Case Jinja::#NODE_ListLiteral
        EvaluateListLiteral(*env, *ctx, *node, *result)

      Case Jinja::#NODE_DictLiteral
        EvaluateDictLiteral(*env, *ctx, *node, *result)

      Case Jinja::#NODE_Call
        EvaluateCall(*env, *ctx, *node, *result)

      Case Jinja::#NODE_If
        ; Inline if expression: value if condition else default
        Protected condV.JinjaVariant::JinjaVariant
        EvaluateExpression(*env, *ctx, *node\Left, @condV)
        If JinjaVariant::IsTruthy(@condV)
          ; Evaluate true branch (first child in Body)
          If *node\Body
            EvaluateExpression(*env, *ctx, *node\Body, *result)
          Else
            JinjaVariant::NullVariant(*result)
          EndIf
        Else
          ; Evaluate else branch (first child in ElseBody)
          If *node\ElseBody
            EvaluateExpression(*env, *ctx, *node\ElseBody, *result)
          Else
            JinjaVariant::StrVariant(*result, "")
          EndIf
        EndIf
        JinjaVariant::FreeVariant(@condV)

      Default
        JinjaVariant::NullVariant(*result)
    EndSelect
  EndProcedure

  ; ===== Node Rendering =====

  Procedure.s RenderText(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ProcedureReturn *node\StringVal
  EndProcedure

  Procedure.s RenderOutput(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    Protected valueV.JinjaVariant::JinjaVariant
    EvaluateExpression(*env, *ctx, *node\Left, @valueV)
    If JinjaError::HasError()
      JinjaVariant::FreeVariant(@valueV)
      ProcedureReturn ""
    EndIf
    Protected result.s = AutoEscape(*env, @valueV)
    JinjaVariant::FreeVariant(@valueV)
    ProcedureReturn result
  EndProcedure

  Procedure.s RenderIf(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ; Evaluate main condition
    Protected condV.JinjaVariant::JinjaVariant
    EvaluateExpression(*env, *ctx, *node\Left, @condV)
    If JinjaError::HasError()
      JinjaVariant::FreeVariant(@condV)
      ProcedureReturn ""
    EndIf

    If JinjaVariant::IsTruthy(@condV)
      JinjaVariant::FreeVariant(@condV)
      ProcedureReturn RenderNodeList(*env, *ctx, *node\Body)
    EndIf
    JinjaVariant::FreeVariant(@condV)

    ; Check elif clauses
    Protected *clause.JinjaAST::ElseIfClause = *node\ElseIfList
    While *clause
      Protected elifCondV.JinjaVariant::JinjaVariant
      EvaluateExpression(*env, *ctx, *clause\Condition, @elifCondV)
      If JinjaVariant::IsTruthy(@elifCondV)
        JinjaVariant::FreeVariant(@elifCondV)
        ProcedureReturn RenderNodeList(*env, *ctx, *clause\Body)
      EndIf
      JinjaVariant::FreeVariant(@elifCondV)
      *clause = *clause\Next
    Wend

    ; Else branch
    ProcedureReturn RenderNodeList(*env, *ctx, *node\ElseBody)
  EndProcedure

  ; --- Core for-loop body rendering helper ---
  ; Iterates over iterV (must be a list), renders body for each item.
  ; Used by both RenderFor and the recursive loop() callable.
  Procedure.s RenderForItems(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode, *iterV.JinjaVariant::JinjaVariant)
    Protected count.i = JinjaVariant::VListSize(*iterV)
    Protected output.s = ""
    Protected i.i

    For i = 0 To count - 1
      JinjaContext::PushScope(*ctx)

      ; Set loop variable
      Protected itemV.JinjaVariant::JinjaVariant
      JinjaVariant::VListGet(*iterV, i, @itemV)
      JinjaContext::SetVariable(*ctx, *node\StringVal, @itemV)
      JinjaVariant::FreeVariant(@itemV)

      ; Set loop.* variables as a map
      Protected loopV.JinjaVariant::JinjaVariant
      JinjaVariant::NewMapVariant(@loopV)

      Protected tmpV.JinjaVariant::JinjaVariant
      JinjaVariant::IntVariant(@tmpV, i + 1)
      JinjaVariant::VMapSet(@loopV, "index", @tmpV)

      JinjaVariant::IntVariant(@tmpV, i)
      JinjaVariant::VMapSet(@loopV, "index0", @tmpV)

      JinjaVariant::BoolVariant(@tmpV, Bool(i = 0))
      JinjaVariant::VMapSet(@loopV, "first", @tmpV)

      JinjaVariant::BoolVariant(@tmpV, Bool(i = count - 1))
      JinjaVariant::VMapSet(@loopV, "last", @tmpV)

      JinjaVariant::IntVariant(@tmpV, count)
      JinjaVariant::VMapSet(@loopV, "length", @tmpV)

      JinjaVariant::IntVariant(@tmpV, count - i)
      JinjaVariant::VMapSet(@loopV, "revindex", @tmpV)

      JinjaVariant::IntVariant(@tmpV, count - i - 1)
      JinjaVariant::VMapSet(@loopV, "revindex0", @tmpV)

      JinjaContext::SetVariable(*ctx, "loop", @loopV)
      JinjaVariant::FreeVariant(@loopV)

      output + RenderNodeList(*env, *ctx, *node\Body)

      JinjaContext::PopScope(*ctx)

      If JinjaError::HasError()
        Break
      EndIf
    Next

    ProcedureReturn output
  EndProcedure

  Procedure.s RenderFor(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ; Evaluate iterable
    Protected iterV.JinjaVariant::JinjaVariant
    EvaluateExpression(*env, *ctx, *node\Left, @iterV)
    If JinjaError::HasError()
      JinjaVariant::FreeVariant(@iterV)
      ProcedureReturn ""
    EndIf

    ; Must be a list
    If iterV\VType <> Jinja::#VT_List
      ; Not iterable - render else body
      JinjaVariant::FreeVariant(@iterV)
      ProcedureReturn RenderNodeList(*env, *ctx, *node\ElseBody)
    EndIf

    Protected count.i = JinjaVariant::VListSize(@iterV)
    If count = 0
      JinjaVariant::FreeVariant(@iterV)
      ProcedureReturn RenderNodeList(*env, *ctx, *node\ElseBody)
    EndIf

    ; For recursive for loops, set up the global context so loop() can re-invoke
    Protected *prevRecNode.JinjaAST::ASTNode = *gRecursiveForNode
    Protected *prevRecEnv.JinjaEnv::JinjaEnvironment = *gRecursiveForEnv
    Protected *prevRecCtx.JinjaContext::JinjaContext = *gRecursiveForCtx

    If *node\IntVal  ; isRecursive
      *gRecursiveForNode = *node
      *gRecursiveForEnv = *env
      *gRecursiveForCtx = *ctx
    EndIf

    Protected output.s = RenderForItems(*env, *ctx, *node, @iterV)

    ; Restore recursive for context
    If *node\IntVal
      *gRecursiveForNode = *prevRecNode
      *gRecursiveForEnv = *prevRecEnv
      *gRecursiveForCtx = *prevRecCtx
    EndIf

    JinjaVariant::FreeVariant(@iterV)
    ProcedureReturn output
  EndProcedure

  Procedure.s RenderSet(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    Protected valueV.JinjaVariant::JinjaVariant
    EvaluateExpression(*env, *ctx, *node\Left, @valueV)
    If Not JinjaError::HasError()
      ; Check for dot-assignment: ns.attr = value
      Protected dotPos.i = FindString(*node\StringVal, ".")
      If dotPos > 0
        Protected objName.s = Left(*node\StringVal, dotPos - 1)
        Protected attrName.s = Mid(*node\StringVal, dotPos + 1)
        If Not JinjaContext::SetVariableMapEntry(*ctx, objName, attrName, @valueV)
          JinjaError::SetError(Jinja::#ERR_Type, "Cannot set attribute '" + attrName + "' on non-map variable '" + objName + "'")
        EndIf
      Else
        JinjaContext::SetVariable(*ctx, *node\StringVal, @valueV)
      EndIf
    EndIf
    JinjaVariant::FreeVariant(@valueV)
    ProcedureReturn ""
  EndProcedure

  Procedure.s RenderBlock(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ProcedureReturn RenderNodeList(*env, *ctx, *node\Body)
  EndProcedure

  Procedure.s RenderInclude(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ; Load and render included template with current context
    If *env\Loader = #Null
      JinjaError::SetError(Jinja::#ERR_Loader, "No loader configured for include")
      ProcedureReturn ""
    EndIf

    Protected source.s = JinjaLoader::LoadTemplate(*env\Loader, *node\StringVal)
    If JinjaError::HasError()
      ProcedureReturn ""
    EndIf

    ; Tokenize
    Protected NewList tokens.JinjaToken::Token()
    JinjaLexer::Tokenize(source, tokens())
    If JinjaError::HasError()
      ProcedureReturn ""
    EndIf

    ; Parse
    Protected *incAST.JinjaAST::ASTNode = JinjaParser::Parse(tokens())
    If JinjaError::HasError()
      ProcedureReturn ""
    EndIf

    ; Render with current context
    Protected result.s = RenderNodeList(*env, *ctx, *incAST\Body)

    ; Free the included AST
    JinjaAST::FreeAST(*incAST)

    ProcedureReturn result
  EndProcedure

  Procedure.s RenderMacro(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ; Register macro in environment for later calling
    *env\MacroDefs(*node\StringVal) = *node
    ProcedureReturn ""
  EndProcedure

  Procedure.s RenderImport(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    ; Load and parse the imported template, then register requested macros
    If *env\Loader = #Null
      JinjaError::SetError(Jinja::#ERR_Loader, "No loader configured for import")
      ProcedureReturn ""
    EndIf

    Protected source.s = JinjaLoader::LoadTemplate(*env\Loader, *node\StringVal)
    If JinjaError::HasError()
      ProcedureReturn ""
    EndIf

    ; Tokenize the imported template
    Protected NewList importTokens.JinjaToken::Token()
    JinjaLexer::Tokenize(source, importTokens())
    If JinjaError::HasError()
      ProcedureReturn ""
    EndIf

    ; Parse the imported template
    Protected *importAST.JinjaAST::ASTNode = JinjaParser::Parse(importTokens())
    If JinjaError::HasError()
      ProcedureReturn ""
    EndIf

    ; Walk the top-level body of the imported template looking for macro definitions
    Protected *child.JinjaAST::ASTNode = *importAST\Body
    While *child
      If *child\NodeType = Jinja::#NODE_Macro
        ; Check if this macro name appears in the import list (our Args)
        Protected *argNode.JinjaAST::ASTNode = *node\Args
        While *argNode
          If *argNode\StringVal = *child\StringVal
            ; Register this macro in the environment
            ; Note: the macro node is owned by *importAST; we must NOT free importAST
            ; below if any macros were registered. We keep the AST alive by leaking it
            ; (acceptable — macros live for the duration of template rendering).
            *env\MacroDefs(*child\StringVal) = *child
          EndIf
          *argNode = *argNode\Next
        Wend
      EndIf
      *child = *child\Next
    Wend

    ; Do NOT free importAST because registered macro nodes are referenced by env\MacroDefs.
    ; The small memory leak is acceptable for the scope of a single render call.

    ProcedureReturn ""
  EndProcedure

  ; ===== Main Node Dispatcher =====

  Procedure.s RenderNode(*env.JinjaEnv::JinjaEnvironment, *ctx.JinjaContext::JinjaContext, *node.JinjaAST::ASTNode)
    If *node = #Null Or JinjaError::HasError()
      ProcedureReturn ""
    EndIf

    Select *node\NodeType
      Case Jinja::#NODE_Template
        ProcedureReturn RenderNodeList(*env, *ctx, *node\Body)

      Case Jinja::#NODE_Text
        ProcedureReturn RenderText(*env, *ctx, *node)

      Case Jinja::#NODE_Output
        ProcedureReturn RenderOutput(*env, *ctx, *node)

      Case Jinja::#NODE_If
        ProcedureReturn RenderIf(*env, *ctx, *node)

      Case Jinja::#NODE_For
        ProcedureReturn RenderFor(*env, *ctx, *node)

      Case Jinja::#NODE_Set
        ProcedureReturn RenderSet(*env, *ctx, *node)

      Case Jinja::#NODE_Block
        ProcedureReturn RenderBlock(*env, *ctx, *node)

      Case Jinja::#NODE_Include
        ProcedureReturn RenderInclude(*env, *ctx, *node)

      Case Jinja::#NODE_Macro
        ProcedureReturn RenderMacro(*env, *ctx, *node)

      Case Jinja::#NODE_Import
        ProcedureReturn RenderImport(*env, *ctx, *node)

      Case Jinja::#NODE_Extends
        ; Handled by ExtendsResolver before rendering
        ProcedureReturn ""

      Case Jinja::#NODE_Call
        ; Evaluate call as expression and return string result
        Protected callResult.JinjaVariant::JinjaVariant
        EvaluateCall(*env, *ctx, *node, @callResult)
        Protected callStr.s = JinjaVariant::ToString(@callResult)
        JinjaVariant::FreeVariant(@callResult)
        ProcedureReturn callStr

      Default
        ProcedureReturn ""
    EndSelect
  EndProcedure

  ; ===== Public API =====

  Procedure.s Render(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode, Map variables.JinjaVariant::JinjaVariant())
    ; Create context and populate with variables
    Protected *ctx.JinjaContext::JinjaContext = JinjaContext::CreateContext()
    JinjaContext::InitFromMap(*ctx, variables())

    ; Render
    Protected result.s = RenderNode(*env, *ctx, *ast)

    ; Cleanup
    JinjaContext::FreeContext(*ctx)

    ProcedureReturn result
  EndProcedure

  Procedure.s RenderWithContext(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode, *ctx.JinjaContext::JinjaContext)
    ProcedureReturn RenderNode(*env, *ctx, *ast)
  EndProcedure

  ; --- Auto-register with Environment (resolves circular dependency) ---
  JinjaEnv::RegisterRenderer(@Render())

EndModule
