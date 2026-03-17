; ============================================================================
; PureJinja - Master Include File
; Jinja2 Template Engine for PureBasic
; Version: 1.3.0
;
; Usage: XIncludeFile "path/to/PureJinja.pbi"
;
; This file includes all library modules in correct dependency order.
; ============================================================================
EnableExplicit

; --- Core ---
XIncludeFile "Core/Constants.pbi"
XIncludeFile "Core/Error.pbi"
XIncludeFile "Core/Variant.pbi"

; --- Lexer ---
XIncludeFile "Lexer/Token.pbi"
XIncludeFile "Lexer/Lexer.pbi"

; --- Parser ---
XIncludeFile "Parser/ASTNode.pbi"
XIncludeFile "Parser/Parser.pbi"

; --- Environment (needed before Renderer for filter prototype) ---
XIncludeFile "Environment/MarkupSafe.pbi"
XIncludeFile "Environment/Filters.pbi"
XIncludeFile "Environment/Loader.pbi"
XIncludeFile "Environment/Environment.pbi"

; --- Renderer ---
XIncludeFile "Renderer/Context.pbi"
XIncludeFile "Renderer/Renderer.pbi"

; --- Inheritance ---
XIncludeFile "Inheritance/ExtendsResolver.pbi"

; --- Renderer auto-registers with Environment via callback (see Renderer.pbi) ---
