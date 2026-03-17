; ============================================================================
; PureJinja - ExtendsResolver.pbi
; Template inheritance: resolves extends/block/super
; Merges child blocks into parent template AST before rendering
; ============================================================================
EnableExplicit

DeclareModule JinjaExtends

  ; Resolve template inheritance.
  ; If the AST contains an {% extends "parent.html" %}, load and merge.
  ; Returns the resolved AST (may be the original or a new merged one).
  Declare.i Resolve(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode)

EndDeclareModule

Module JinjaExtends

  ; --- Collect all block nodes from an AST into a map ---
  Procedure CollectBlocks(*node.JinjaAST::ASTNode, Map blocks.i())
    If *node = #Null
      ProcedureReturn
    EndIf

    ; Check direct children
    Protected *child.JinjaAST::ASTNode = *node\Body
    While *child
      If *child\NodeType = Jinja::#NODE_Block
        blocks(*child\StringVal) = *child  ; Map block name -> block node pointer
      EndIf
      *child = *child\Next
    Wend
  EndProcedure

  ; --- Deep-clone a node list, replacing blocks with child overrides ---
  Declare.i CloneAndMergeNode(*node.JinjaAST::ASTNode, Map childBlocks.i(), Map parentBlockContent.i())

  Procedure.i CloneAndMergeNodeList(*head.JinjaAST::ASTNode, Map childBlocks.i(), Map parentBlockContent.i())
    Protected *result.JinjaAST::ASTNode = #Null
    Protected *last.JinjaAST::ASTNode = #Null
    Protected *current.JinjaAST::ASTNode = *head

    While *current
      Protected *cloned.JinjaAST::ASTNode = CloneAndMergeNode(*current, childBlocks(), parentBlockContent())
      If *cloned
        If *result = #Null
          *result = *cloned
          *last = *cloned
        Else
          *last\Next = *cloned
          *last = *cloned
        EndIf
        *last\Next = #Null
      EndIf
      *current = *current\Next
    Wend

    ProcedureReturn *result
  EndProcedure

  Procedure.i CloneAndMergeNode(*node.JinjaAST::ASTNode, Map childBlocks.i(), Map parentBlockContent.i())
    If *node = #Null
      ProcedureReturn #Null
    EndIf

    If *node\NodeType = Jinja::#NODE_Block
      ; Check if child overrides this block
      If FindMapElement(childBlocks(), *node\StringVal)
        Protected *childBlock.JinjaAST::ASTNode = childBlocks(*node\StringVal)
        ; Store parent block content for super() support
        parentBlockContent(*node\StringVal) = *node

        ; Clone the child block, preserving its name
        Protected *newBlock.JinjaAST::ASTNode = JinjaAST::NewBlockNode(*node\StringVal, *childBlock\LineNumber)
        *newBlock\Body = CloneAndMergeNodeList(*childBlock\Body, childBlocks(), parentBlockContent())
        ProcedureReturn *newBlock
      Else
        ; Keep parent's default content
        Protected *keepBlock.JinjaAST::ASTNode = JinjaAST::NewBlockNode(*node\StringVal, *node\LineNumber)
        *keepBlock\Body = CloneAndMergeNodeList(*node\Body, childBlocks(), parentBlockContent())
        ProcedureReturn *keepBlock
      EndIf
    EndIf

    ; For non-block nodes, clone as-is (shallow enough for text/output)
    Select *node\NodeType
      Case Jinja::#NODE_Text
        ProcedureReturn JinjaAST::NewTextNode(*node\StringVal, *node\LineNumber)

      Case Jinja::#NODE_Output
        ; Clone with a reference to the same expression (shared, not deep-cloned)
        Protected *outNode.JinjaAST::ASTNode = JinjaAST::NewOutputNode(*node\Left, *node\LineNumber)
        *outNode\Left = *node\Left  ; Share expression tree (don't free independently)
        ProcedureReturn *outNode

      Default
        ; For all other node types, we reference-share them from the parent
        ; This is safe because we don't modify AST after resolution
        ProcedureReturn *node
    EndSelect
  EndProcedure

  ; ===== Main Resolution =====

  Procedure.i Resolve(*env.JinjaEnv::JinjaEnvironment, *ast.JinjaAST::ASTNode)
    If *ast = #Null
      ProcedureReturn *ast
    EndIf

    ; Find extends node (must be among top-level children)
    Protected *extendsNode.JinjaAST::ASTNode = #Null
    Protected *child.JinjaAST::ASTNode = *ast\Body
    While *child
      If *child\NodeType = Jinja::#NODE_Extends
        *extendsNode = *child
        Break
      EndIf
      *child = *child\Next
    Wend

    ; No inheritance - return as-is
    If *extendsNode = #Null
      ProcedureReturn *ast
    EndIf

    ; Need loader to resolve parent
    If *env\Loader = #Null
      JinjaError::SetError(Jinja::#ERR_Inheritance, "No loader configured for template inheritance")
      ProcedureReturn *ast
    EndIf

    ; Load and parse parent template
    Protected parentSource.s = JinjaLoader::LoadTemplate(*env\Loader, *extendsNode\StringVal)
    If JinjaError::HasError()
      ProcedureReturn *ast
    EndIf

    Protected NewList parentTokens.JinjaToken::Token()
    JinjaLexer::Tokenize(parentSource, parentTokens())
    If JinjaError::HasError()
      ProcedureReturn *ast
    EndIf

    Protected *parentAST.JinjaAST::ASTNode = JinjaParser::Parse(parentTokens())
    If JinjaError::HasError()
      ProcedureReturn *ast
    EndIf

    ; Recursively resolve parent's inheritance
    *parentAST = Resolve(*env, *parentAST)
    If JinjaError::HasError()
      ProcedureReturn *ast
    EndIf

    ; Collect child blocks
    Protected NewMap childBlocks.i()
    CollectBlocks(*ast, childBlocks())

    ; Merge: clone parent AST with child block overrides
    Protected NewMap parentBlockContent.i()
    Protected *mergedRoot.JinjaAST::ASTNode = JinjaAST::NewTemplateNode()
    *mergedRoot\Body = CloneAndMergeNodeList(*parentAST\Body, childBlocks(), parentBlockContent())

    ProcedureReturn *mergedRoot
  EndProcedure

  ; --- Auto-register with Environment (resolves circular dependency) ---
  JinjaEnv::RegisterResolver(@Resolve())

EndModule
