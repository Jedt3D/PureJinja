; ============================================================================
; PureJinja - ASTNode.pbi
; AST node structure and constructors for the parsed template tree
; Uses a single flat structure with type-dispatch (no class inheritance)
; ============================================================================
EnableExplicit

DeclareModule JinjaAST

  ; --- ElseIf Clause (for if/elif chains) ---
  Structure ElseIfClause
    *Condition.ASTNode     ; The elif condition expression
    *Body.ASTNode          ; First node in body linked list
    *Next.ElseIfClause     ; Next elif clause
  EndStructure

  ; --- AST Node Structure ---
  ; Single structure for all node types, dispatched by NodeType field
  Structure ASTNode
    NodeType.i             ; NodeType enum from Constants.pbi
    LineNumber.i           ; Source line for error reporting

    ; --- String fields (used differently per node type) ---
    StringVal.s            ; Text content, variable name, operator, filter name, block name, template name
    StringVal2.s           ; Second string (e.g., block name at endblock, macro param names CSV)

    ; --- Numeric fields ---
    IntVal.q               ; Literal integer, literal subtype, boolean value
    DblVal.d               ; Literal double

    ; --- Child pointers ---
    *Left.ASTNode          ; Left operand, condition, expression, object
    *Right.ASTNode         ; Right operand, index expression

    *Body.ASTNode          ; First child in body list (linked via *Next)
    *ElseBody.ASTNode      ; First child in else body list
    *Next.ASTNode          ; Next sibling (linked list)

    ; --- Argument list ---
    *Args.ASTNode          ; First argument in linked list (for filters, calls, list literals)

    ; --- ElseIf chain (for if nodes) ---
    *ElseIfList.ElseIfClause  ; First elif clause

    ; --- Macro parameter names stored in StringVal2 as comma-separated ---
    ; --- (e.g., "param1,param2,param3") ---
  EndStructure

  ; --- Constructors ---
  Declare.i NewTemplateNode()
  Declare.i NewTextNode(text.s, lineNum.i = 0)
  Declare.i NewOutputNode(*expression.ASTNode, lineNum.i = 0)
  Declare.i NewLiteralStringNode(value.s, lineNum.i = 0)
  Declare.i NewLiteralIntNode(value.q, lineNum.i = 0)
  Declare.i NewLiteralFloatNode(value.d, lineNum.i = 0)
  Declare.i NewLiteralBoolNode(value.i, lineNum.i = 0)
  Declare.i NewLiteralNoneNode(lineNum.i = 0)
  Declare.i NewVariableNode(name.s, lineNum.i = 0)
  Declare.i NewBinaryOpNode(*left.ASTNode, operator.s, *right.ASTNode, lineNum.i = 0)
  Declare.i NewUnaryOpNode(operator.s, *operand.ASTNode, lineNum.i = 0)
  Declare.i NewCompareNode(*left.ASTNode, operator.s, *right.ASTNode, lineNum.i = 0)
  Declare.i NewFilterNode(*expression.ASTNode, filterName.s, lineNum.i = 0)
  Declare.i NewGetAttrNode(*obj.ASTNode, attr.s, lineNum.i = 0)
  Declare.i NewGetItemNode(*obj.ASTNode, *index.ASTNode, lineNum.i = 0)
  Declare.i NewIfNode(*condition.ASTNode, lineNum.i = 0)
  Declare.i NewForNode(varName.s, *iterable.ASTNode, lineNum.i = 0)
  Declare.i NewSetNode(varName.s, *value.ASTNode, lineNum.i = 0)
  Declare.i NewBlockNode(blockName.s, lineNum.i = 0)
  Declare.i NewExtendsNode(templateName.s, lineNum.i = 0)
  Declare.i NewIncludeNode(templateName.s, lineNum.i = 0)
  Declare.i NewMacroNode(macroName.s, lineNum.i = 0)
  Declare.i NewCallNode(funcName.s, lineNum.i = 0)
  Declare.i NewListLiteralNode(lineNum.i = 0)

  ; --- Tree manipulation ---
  Declare AddChild(*parent.ASTNode, *child.ASTNode)
  Declare AddElseChild(*parent.ASTNode, *child.ASTNode)
  Declare AddArg(*parent.ASTNode, *arg.ASTNode)
  Declare.i AddElseIf(*ifNode.ASTNode, *condition.ASTNode)
  Declare AddElseIfBody(*clause.ElseIfClause, *child.ASTNode)
  Declare AddMacroParam(*macroNode.ASTNode, paramName.s)

  ; --- Memory management ---
  Declare FreeAST(*node.ASTNode)

EndDeclareModule

Module JinjaAST

  ; --- Internal: allocate a new node ---
  Procedure.i AllocNode(nodeType.i, lineNum.i)
    Protected *node.ASTNode = AllocateStructure(ASTNode)
    If *node
      *node\NodeType = nodeType
      *node\LineNumber = lineNum
      *node\StringVal = ""
      *node\StringVal2 = ""
      *node\IntVal = 0
      *node\DblVal = 0.0
      *node\Left = #Null
      *node\Right = #Null
      *node\Body = #Null
      *node\ElseBody = #Null
      *node\Next = #Null
      *node\Args = #Null
      *node\ElseIfList = #Null
    EndIf
    ProcedureReturn *node
  EndProcedure

  ; ===== Constructors =====

  Procedure.i NewTemplateNode()
    ProcedureReturn AllocNode(Jinja::#NODE_Template, 0)
  EndProcedure

  Procedure.i NewTextNode(text.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Text, lineNum)
    If *node
      *node\StringVal = text
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewOutputNode(*expression.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Output, lineNum)
    If *node
      *node\Left = *expression
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewLiteralStringNode(value.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Literal, lineNum)
    If *node
      *node\IntVal = Jinja::#LIT_String
      *node\StringVal = value
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewLiteralIntNode(value.q, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Literal, lineNum)
    If *node
      *node\IntVal = Jinja::#LIT_Integer
      *node\DblVal = value * 1.0  ; Store for numeric ops
      *node\StringVal = Str(value)
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewLiteralFloatNode(value.d, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Literal, lineNum)
    If *node
      *node\IntVal = Jinja::#LIT_Float
      *node\DblVal = value
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewLiteralBoolNode(value.i, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Literal, lineNum)
    If *node
      *node\IntVal = Jinja::#LIT_Boolean
      If value
        *node\DblVal = 1.0
      Else
        *node\DblVal = 0.0
      EndIf
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewLiteralNoneNode(lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Literal, lineNum)
    If *node
      *node\IntVal = Jinja::#LIT_None
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewVariableNode(name.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Variable, lineNum)
    If *node
      *node\StringVal = name
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewBinaryOpNode(*left.ASTNode, operator.s, *right.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_BinaryOp, lineNum)
    If *node
      *node\Left = *left
      *node\Right = *right
      *node\StringVal = operator
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewUnaryOpNode(operator.s, *operand.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_UnaryOp, lineNum)
    If *node
      *node\Left = *operand
      *node\StringVal = operator
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewCompareNode(*left.ASTNode, operator.s, *right.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Compare, lineNum)
    If *node
      *node\Left = *left
      *node\Right = *right
      *node\StringVal = operator
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewFilterNode(*expression.ASTNode, filterName.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Filter, lineNum)
    If *node
      *node\Left = *expression
      *node\StringVal = filterName
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewGetAttrNode(*obj.ASTNode, attr.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_GetAttr, lineNum)
    If *node
      *node\Left = *obj
      *node\StringVal = attr
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewGetItemNode(*obj.ASTNode, *index.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_GetItem, lineNum)
    If *node
      *node\Left = *obj
      *node\Right = *index
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewIfNode(*condition.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_If, lineNum)
    If *node
      *node\Left = *condition
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewForNode(varName.s, *iterable.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_For, lineNum)
    If *node
      *node\StringVal = varName
      *node\Left = *iterable   ; Iterable expression
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewSetNode(varName.s, *value.ASTNode, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Set, lineNum)
    If *node
      *node\StringVal = varName
      *node\Left = *value
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewBlockNode(blockName.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Block, lineNum)
    If *node
      *node\StringVal = blockName
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewExtendsNode(templateName.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Extends, lineNum)
    If *node
      *node\StringVal = templateName
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewIncludeNode(templateName.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Include, lineNum)
    If *node
      *node\StringVal = templateName
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewMacroNode(macroName.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Macro, lineNum)
    If *node
      *node\StringVal = macroName
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewCallNode(funcName.s, lineNum.i = 0)
    Protected *node.ASTNode = AllocNode(Jinja::#NODE_Call, lineNum)
    If *node
      *node\StringVal = funcName
    EndIf
    ProcedureReturn *node
  EndProcedure

  Procedure.i NewListLiteralNode(lineNum.i = 0)
    ProcedureReturn AllocNode(Jinja::#NODE_ListLiteral, lineNum)
  EndProcedure

  ; ===== Tree Manipulation =====

  Procedure AddChild(*parent.ASTNode, *child.ASTNode)
    ; Add *child to the end of *parent's Body linked list
    If *parent = #Null Or *child = #Null
      ProcedureReturn
    EndIf

    If *parent\Body = #Null
      *parent\Body = *child
    Else
      Protected *last.ASTNode = *parent\Body
      While *last\Next
        *last = *last\Next
      Wend
      *last\Next = *child
    EndIf
    *child\Next = #Null
  EndProcedure

  Procedure AddElseChild(*parent.ASTNode, *child.ASTNode)
    ; Add *child to the end of *parent's ElseBody linked list
    If *parent = #Null Or *child = #Null
      ProcedureReturn
    EndIf

    If *parent\ElseBody = #Null
      *parent\ElseBody = *child
    Else
      Protected *last.ASTNode = *parent\ElseBody
      While *last\Next
        *last = *last\Next
      Wend
      *last\Next = *child
    EndIf
    *child\Next = #Null
  EndProcedure

  Procedure AddArg(*parent.ASTNode, *arg.ASTNode)
    ; Add *arg to the end of *parent's Args linked list
    If *parent = #Null Or *arg = #Null
      ProcedureReturn
    EndIf

    If *parent\Args = #Null
      *parent\Args = *arg
    Else
      Protected *last.ASTNode = *parent\Args
      While *last\Next
        *last = *last\Next
      Wend
      *last\Next = *arg
    EndIf
    *arg\Next = #Null
  EndProcedure

  Procedure.i AddElseIf(*ifNode.ASTNode, *condition.ASTNode)
    ; Add a new elif clause to the if node. Returns pointer to the new clause.
    Protected *clause.ElseIfClause = AllocateStructure(ElseIfClause)
    If *clause = #Null
      ProcedureReturn #Null
    EndIf

    *clause\Condition = *condition
    *clause\Body = #Null
    *clause\Next = #Null

    ; Append to end of elif chain
    If *ifNode\ElseIfList = #Null
      *ifNode\ElseIfList = *clause
    Else
      Protected *last.ElseIfClause = *ifNode\ElseIfList
      While *last\Next
        *last = *last\Next
      Wend
      *last\Next = *clause
    EndIf

    ProcedureReturn *clause
  EndProcedure

  Procedure AddElseIfBody(*clause.ElseIfClause, *child.ASTNode)
    ; Add a child to an elif clause's body
    If *clause = #Null Or *child = #Null
      ProcedureReturn
    EndIf

    If *clause\Body = #Null
      *clause\Body = *child
    Else
      Protected *last.ASTNode = *clause\Body
      While *last\Next
        *last = *last\Next
      Wend
      *last\Next = *child
    EndIf
    *child\Next = #Null
  EndProcedure

  Procedure AddMacroParam(*macroNode.ASTNode, paramName.s)
    ; Add a parameter name to a macro node (stored as CSV in StringVal2)
    If *macroNode\StringVal2 = ""
      *macroNode\StringVal2 = paramName
    Else
      *macroNode\StringVal2 + "," + paramName
    EndIf
  EndProcedure

  ; ===== Memory Management =====

  Procedure FreeNodeList(*node.ASTNode)
    ; Free a linked list of nodes (following ->Next)
    Protected *current.ASTNode = *node
    Protected *next.ASTNode
    While *current
      *next = *current\Next
      FreeAST(*current)
      *current = *next
    Wend
  EndProcedure

  Procedure FreeAST(*node.ASTNode)
    If *node = #Null
      ProcedureReturn
    EndIf

    ; Free child trees (but NOT ->Next since FreeNodeList handles that)
    If *node\Left
      FreeAST(*node\Left)
    EndIf
    If *node\Right
      FreeAST(*node\Right)
    EndIf

    ; Free body and else body linked lists
    If *node\Body
      FreeNodeList(*node\Body)
    EndIf
    If *node\ElseBody
      FreeNodeList(*node\ElseBody)
    EndIf

    ; Free argument linked list
    If *node\Args
      FreeNodeList(*node\Args)
    EndIf

    ; Free elif clauses
    Protected *clause.ElseIfClause = *node\ElseIfList
    Protected *nextClause.ElseIfClause
    While *clause
      *nextClause = *clause\Next
      If *clause\Condition
        FreeAST(*clause\Condition)
      EndIf
      If *clause\Body
        FreeNodeList(*clause\Body)
      EndIf
      FreeStructure(*clause)
      *clause = *nextClause
    Wend

    FreeStructure(*node)
  EndProcedure

EndModule
