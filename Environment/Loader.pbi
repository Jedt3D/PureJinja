; ============================================================================
; PureJinja - Loader.pbi
; Template loaders: FileSystem and Dictionary-based
; ============================================================================
EnableExplicit

DeclareModule JinjaLoader

  ; --- Loader Types ---
  Enumeration LoaderType
    #LOADER_None = 0
    #LOADER_FileSystem
    #LOADER_Dict
  EndEnumeration

  ; --- Loader Structure ---
  Structure TemplateLoader
    LoaderType.i
    BasePath.s                         ; For filesystem loader
    Map Templates.s()                  ; For dict loader
  EndStructure

  ; --- API ---
  Declare.i CreateFileSystemLoader(basePath.s)
  Declare.i CreateDictLoader()
  Declare FreeLoader(*loader.TemplateLoader)
  Declare DictLoaderAdd(*loader.TemplateLoader, name.s, source.s)
  Declare.s LoadTemplate(*loader.TemplateLoader, name.s)
  Declare.i TemplateExists(*loader.TemplateLoader, name.s)

EndDeclareModule

Module JinjaLoader

  Procedure.i CreateFileSystemLoader(basePath.s)
    Protected *loader.TemplateLoader = AllocateStructure(TemplateLoader)
    If *loader
      *loader\LoaderType = #LOADER_FileSystem
      ; Ensure base path ends with separator
      If basePath <> "" And Right(basePath, 1) <> "/" And Right(basePath, 1) <> "\"
        basePath + "/"
      EndIf
      *loader\BasePath = basePath
    EndIf
    ProcedureReturn *loader
  EndProcedure

  Procedure.i CreateDictLoader()
    Protected *loader.TemplateLoader = AllocateStructure(TemplateLoader)
    If *loader
      *loader\LoaderType = #LOADER_Dict
      *loader\BasePath = ""
    EndIf
    ProcedureReturn *loader
  EndProcedure

  Procedure FreeLoader(*loader.TemplateLoader)
    If *loader
      FreeStructure(*loader)
    EndIf
  EndProcedure

  Procedure DictLoaderAdd(*loader.TemplateLoader, name.s, source.s)
    If *loader And *loader\LoaderType = #LOADER_Dict
      *loader\Templates(name) = source
    EndIf
  EndProcedure

  Procedure.s LoadTemplate(*loader.TemplateLoader, name.s)
    If *loader = #Null
      JinjaError::SetError(Jinja::#ERR_Loader, "No loader configured")
      ProcedureReturn ""
    EndIf

    Select *loader\LoaderType
      Case #LOADER_FileSystem
        Protected filePath.s = *loader\BasePath + name
        Protected file.i = ReadFile(#PB_Any, filePath)
        If file = 0
          JinjaError::SetError(Jinja::#ERR_Loader, "Template not found: " + name + " (path: " + filePath + ")")
          ProcedureReturn ""
        EndIf
        Protected content.s = ReadString(file, #PB_UTF8 | #PB_File_IgnoreEOL)
        CloseFile(file)
        ProcedureReturn content

      Case #LOADER_Dict
        If FindMapElement(*loader\Templates(), name)
          ProcedureReturn *loader\Templates(name)
        Else
          JinjaError::SetError(Jinja::#ERR_Loader, "Template not found in dict: " + name)
          ProcedureReturn ""
        EndIf

      Default
        JinjaError::SetError(Jinja::#ERR_Loader, "Invalid loader type")
        ProcedureReturn ""
    EndSelect
  EndProcedure

  Procedure.i TemplateExists(*loader.TemplateLoader, name.s)
    If *loader = #Null
      ProcedureReturn #False
    EndIf

    Select *loader\LoaderType
      Case #LOADER_FileSystem
        Protected filePath.s = *loader\BasePath + name
        ProcedureReturn Bool(FileSize(filePath) >= 0)

      Case #LOADER_Dict
        ProcedureReturn Bool(FindMapElement(*loader\Templates(), name) <> 0)

      Default
        ProcedureReturn #False
    EndSelect
  EndProcedure

EndModule
