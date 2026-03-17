; ============================================================================
; PureJinja - Constants.pbi
; All enumerations and constants for the Jinja2 template engine
; ============================================================================
EnableExplicit

DeclareModule Jinja

  ; --- Variant Types ---
  ; Represents the dynamic type of a JinjaVariant value
  Enumeration VariantType
    #VT_Null = 0      ; No value / None
    #VT_Boolean        ; Boolean true/false
    #VT_Integer        ; 64-bit integer
    #VT_Double         ; Double-precision float
    #VT_String         ; String value
    #VT_List           ; Pointer to a list of JinjaVariant
    #VT_Map            ; Pointer to a map of JinjaVariant
    #VT_Markup         ; Safe HTML string (no auto-escape)
  EndEnumeration

  ; --- Token Types ---
  ; Produced by the Lexer for the Parser to consume
  Enumeration TokenType
    #TK_EOF = 0            ; End of input
    #TK_Data               ; Raw text outside of blocks
    #TK_VariableBegin      ; {{
    #TK_VariableEnd        ; }}
    #TK_BlockBegin         ; {%
    #TK_BlockEnd           ; %}
    #TK_CommentBegin       ; {#
    #TK_CommentEnd         ; #}
    #TK_Name               ; Identifier (variable name, function name)
    #TK_Keyword            ; Reserved keyword (if, for, etc.)
    #TK_String             ; String literal
    #TK_Integer            ; Integer literal
    #TK_Float              ; Float literal
    #TK_Operator           ; Operator (+, -, *, /, ==, !=, etc.)
    #TK_Assign             ; = (assignment)
    #TK_Pipe               ; | (filter separator)
    #TK_Dot                ; . (attribute access)
    #TK_Comma              ; ,
    #TK_Colon              ; :
    #TK_LParen             ; (
    #TK_RParen             ; )
    #TK_LBracket           ; [
    #TK_RBracket           ; ]
    #TK_LBrace             ; {
    #TK_RBrace             ; }
    #TK_Tilde              ; ~ (string concatenation)
  EndEnumeration

  ; --- AST Node Types ---
  ; Every node in the parsed tree has one of these types
  Enumeration NodeType
    #NODE_Template = 0     ; Root node containing a list of child nodes
    #NODE_Text             ; Raw text content
    #NODE_Output           ; {{ expression }} output
    #NODE_Literal          ; Literal value (string, int, float, bool, none)
    #NODE_Variable         ; Variable reference by name
    #NODE_BinaryOp         ; Binary operation (a + b, a and b, etc.)
    #NODE_UnaryOp          ; Unary operation (not x, -x)
    #NODE_Compare          ; Comparison (==, !=, <, >, in, is, etc.)
    #NODE_Filter           ; Filter application (value|filtername)
    #NODE_GetAttr          ; Attribute access (obj.attr)
    #NODE_GetItem          ; Item access (obj[key])
    #NODE_If               ; If/elif/else conditional
    #NODE_For              ; For loop
    #NODE_Set              ; Variable assignment
    #NODE_Block            ; Named block (for inheritance)
    #NODE_Extends          ; Template inheritance
    #NODE_Include          ; Template inclusion
    #NODE_Macro            ; Macro definition
    #NODE_Call             ; Macro/function call
    #NODE_ListLiteral      ; List literal [a, b, c]
    #NODE_DictLiteral      ; Dict literal {"key": value}
  EndEnumeration

  ; --- Literal Sub-Types ---
  ; Used in LiteralNode to distinguish the value type
  Enumeration LiteralType
    #LIT_String = 0
    #LIT_Integer
    #LIT_Float
    #LIT_Boolean
    #LIT_None
  EndEnumeration

  ; --- Error Codes ---
  Enumeration ErrorCode
    #ERR_None = 0          ; No error
    #ERR_Syntax            ; Template syntax error (lexer/parser)
    #ERR_Render            ; Rendering error
    #ERR_Undefined         ; Undefined variable
    #ERR_Type              ; Type mismatch
    #ERR_Filter            ; Unknown or bad filter
    #ERR_Loader            ; Template loading error
    #ERR_Inheritance       ; Template inheritance error
    #ERR_Internal          ; Internal engine error
  EndEnumeration

  ; --- Engine Constants ---
  #JINJA_VERSION$ = "1.2.0"
  #JINJA_MAX_RECURSION = 100

EndDeclareModule

Module Jinja
  ; Constants module has no implementation - all values are in DeclareModule
EndModule
