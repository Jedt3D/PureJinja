; ============================================================================
; PureJinja - Environment.pbi
; Main configuration and public API for the template engine
; ============================================================================
EnableExplicit

DeclareModule JinjaEnv

  ; --- Filter function prototype ---
  ; All filters: procedure(*value.JinjaVariant, *args.JinjaVariant, argCount.i, *result.JinjaVariant)
  Prototype ProtoFilter(*value.JinjaVariant::JinjaVariant, *args.JinjaVariant::JinjaVariant, argCount.i, *result.JinjaVariant::JinjaVariant)

  ; --- Renderer callback prototype ---
  ; Called by RenderString/RenderTemplate to invoke the Renderer module
  Prototype.s ProtoRenderCallback(*env, *ast.JinjaAST::ASTNode, Map variables.JinjaVariant::JinjaVariant())

  ; --- ExtendsResolver callback prototype ---
  ; Called to resolve template inheritance before rendering
  Prototype.i ProtoResolveCallback(*env, *ast.JinjaAST::ASTNode)

  ; --- Environment Structure ---
  Structure JinjaEnvironment
    Autoescape.i                       ; #True to auto-escape HTML output
    TrimBlocks.i                       ; #True to trim first newline after block
    LStripBlocks.i                     ; #True to strip leading whitespace from block lines
    Map Filters.i()                    ; Filter name -> procedure address
    *Loader.JinjaLoader::TemplateLoader  ; Template loader
    Map TemplateCache.s()              ; Template source cache (name -> source)
    Map MacroDefs.i()                  ; Macro name -> *ASTNode for macro definitions
  EndStructure

  ; --- Public API ---
  Declare.i CreateEnvironment()
  Declare FreeEnvironment(*env.JinjaEnvironment)
  Declare RegisterFilter(*env.JinjaEnvironment, name.s, *filterProc)
  Declare.i GetFilter(*env.JinjaEnvironment, name.s)
  Declare.i HasFilter(*env.JinjaEnvironment, name.s)
  Declare SetLoader(*env.JinjaEnvironment, *loader.JinjaLoader::TemplateLoader)
  Declare SetTemplatePath(*env.JinjaEnvironment, path.s)

  ; --- Runtime Registration (called by Renderer.pbi and ExtendsResolver.pbi on load) ---
  Declare RegisterRenderer(*renderProc)
  Declare RegisterResolver(*resolveProc)

  ; --- Template Operations ---
  Declare.s RenderString(*env.JinjaEnvironment, templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  Declare.s RenderTemplate(*env.JinjaEnvironment, templateName.s, Map variables.JinjaVariant::JinjaVariant())
  Declare.s LoadTemplateSource(*env.JinjaEnvironment, name.s)

EndDeclareModule

Module JinjaEnv

  ; --- Runtime callbacks (set by RegisterRenderer/RegisterResolver) ---
  Global gRenderCallback.i = #Null
  Global gResolveCallback.i = #Null

  Procedure RegisterRenderer(*renderProc)
    gRenderCallback = *renderProc
  EndProcedure

  Procedure RegisterResolver(*resolveProc)
    gResolveCallback = *resolveProc
  EndProcedure

  Procedure.i CreateEnvironment()
    Protected *env.JinjaEnvironment = AllocateStructure(JinjaEnvironment)
    If *env
      *env\Autoescape = #True
      *env\TrimBlocks = #False
      *env\LStripBlocks = #False
      *env\Loader = #Null

      ; Register all built-in filters
      JinjaFilters::RegisterAll(*env\Filters())
    EndIf
    ProcedureReturn *env
  EndProcedure

  Procedure FreeEnvironment(*env.JinjaEnvironment)
    If *env
      If *env\Loader
        JinjaLoader::FreeLoader(*env\Loader)
      EndIf
      FreeStructure(*env)
    EndIf
  EndProcedure

  Procedure RegisterFilter(*env.JinjaEnvironment, name.s, *filterProc)
    If *env And *filterProc
      *env\Filters(name) = *filterProc
    EndIf
  EndProcedure

  Procedure.i GetFilter(*env.JinjaEnvironment, name.s)
    If *env
      If FindMapElement(*env\Filters(), name)
        ProcedureReturn *env\Filters(name)
      EndIf
    EndIf
    ProcedureReturn #Null
  EndProcedure

  Procedure.i HasFilter(*env.JinjaEnvironment, name.s)
    If *env
      ProcedureReturn Bool(FindMapElement(*env\Filters(), name) <> 0)
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure SetLoader(*env.JinjaEnvironment, *loader.JinjaLoader::TemplateLoader)
    If *env
      If *env\Loader
        JinjaLoader::FreeLoader(*env\Loader)
      EndIf
      *env\Loader = *loader
    EndIf
  EndProcedure

  Procedure SetTemplatePath(*env.JinjaEnvironment, path.s)
    If *env
      Protected *loader.JinjaLoader::TemplateLoader = JinjaLoader::CreateFileSystemLoader(path)
      SetLoader(*env, *loader)
    EndIf
  EndProcedure

  Procedure.s LoadTemplateSource(*env.JinjaEnvironment, name.s)
    If *env And *env\Loader
      ProcedureReturn JinjaLoader::LoadTemplate(*env\Loader, name)
    EndIf
    JinjaError::SetError(Jinja::#ERR_Loader, "No loader configured")
    ProcedureReturn ""
  EndProcedure

  Procedure.s RenderString(*env.JinjaEnvironment, templateStr.s, Map variables.JinjaVariant::JinjaVariant())
    If gRenderCallback = #Null
      JinjaError::SetError(Jinja::#ERR_Internal, "Renderer not registered")
      ProcedureReturn "[Error] " + JinjaError::FormatError()
    EndIf

    ; Tokenize
    Protected NewList tokens.JinjaToken::Token()
    JinjaError::ClearError()
    JinjaLexer::Tokenize(templateStr, tokens())
    If JinjaError::HasError()
      ProcedureReturn "[Error] " + JinjaError::FormatError()
    EndIf

    ; Parse
    Protected *ast.JinjaAST::ASTNode = JinjaParser::Parse(tokens())
    If JinjaError::HasError()
      ProcedureReturn "[Error] " + JinjaError::FormatError()
    EndIf

    ; Resolve inheritance (if extends is present and resolver is registered)
    If gResolveCallback And *env\Loader
      Protected resolveProc.ProtoResolveCallback = gResolveCallback
      Protected *resolved.JinjaAST::ASTNode = resolveProc(*env, *ast)
      If *resolved <> *ast
        ; Resolve returned a new merged AST.
        ; NOTE: Do NOT free the child *ast here — the resolver shares child
        ; block-body nodes with *resolved without deep-copying them.  Freeing
        ; *ast would leave dangling pointers inside *resolved, causing a
        ; use-after-free crash during rendering.  The child structural nodes
        ; (TemplateNode, ExtendsNode, BlockNode shells) become a small bounded
        ; leak per render call; the shared block-body nodes are freed when
        ; *resolved is freed after rendering (line below).
        *ast = *resolved
      EndIf
      If JinjaError::HasError()
        JinjaAST::FreeAST(*ast)
        ProcedureReturn "[Error] " + JinjaError::FormatError()
      EndIf
    EndIf

    ; Render via callback to JinjaRenderer::Render
    Protected renderProc.ProtoRenderCallback = gRenderCallback
    Protected result.s = renderProc(*env, *ast, variables())
    JinjaAST::FreeAST(*ast)
    ProcedureReturn result
  EndProcedure

  Procedure.s RenderTemplate(*env.JinjaEnvironment, templateName.s, Map variables.JinjaVariant::JinjaVariant())
    If *env = #Null Or *env\Loader = #Null
      ProcedureReturn "[Error] No loader configured"
    EndIf

    Protected source.s = JinjaLoader::LoadTemplate(*env\Loader, templateName)
    If JinjaError::HasError()
      ProcedureReturn "[Error] " + JinjaError::FormatError()
    EndIf

    ProcedureReturn RenderString(*env, source, variables())
  EndProcedure

EndModule
