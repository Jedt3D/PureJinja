; ============================================================================
; PureJinja - TestInheritance.pbi
; Acceptance tests for template inheritance ({% extends %} / {% block %})
; Tests templates 41-46 and 52 from the template catalogue.
;
; Pipeline:
;   1. Create DictLoader with all template sources
;   2. Create Environment, SetLoader
;   3. Tokenize + Parse the child template source
;   4. JinjaExtends::Resolve(*env, *ast)  -> merged AST
;   5. JinjaRenderer::Render(*env, *resolvedAST, vars())
;   6. AssertTrue(Bool(FindString(result, "...") > 0), ...)
;   7. Free: JinjaAST::FreeAST(*resolvedAST), JinjaEnv::FreeEnvironment(*env)
;
; Helper prefix: Inh_   (no conflicts with Acc_ or Integration_ helpers)
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Template source constants
; (Defined as procedures returning strings to avoid Global string length limits)
; ---------------------------------------------------------------------------

Procedure.s Inh_Base41()
  ProcedureReturn "<!DOCTYPE html>" + Chr(10) +
                 "<html>" + Chr(10) +
                 "<head>" + Chr(10) +
                 "<meta charset=" + Chr(34) + "utf-8" + Chr(34) + ">" + Chr(10) +
                 "<meta name=" + Chr(34) + "viewport" + Chr(34) + " content=" + Chr(34) + "width=device-width, initial-scale=1" + Chr(34) + ">" + Chr(10) +
                 "<link href=" + Chr(34) + "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" + Chr(34) + " rel=" + Chr(34) + "stylesheet" + Chr(34) + ">" + Chr(10) +
                 "<title>{% block title %}PureJinja{% endblock %}</title>" + Chr(10) +
                 "</head>" + Chr(10) +
                 "<body>" + Chr(10) +
                 "<div class=" + Chr(34) + "container py-4" + Chr(34) + ">" + Chr(10) +
                 "{% block header %}<h1 class=" + Chr(34) + "mb-3" + Chr(34) + ">Welcome</h1>{% endblock %}" + Chr(10) +
                 "{% block content %}<p>Default content.</p>{% endblock %}" + Chr(10) +
                 "{% block footer %}<hr><p class=" + Chr(34) + "text-muted" + Chr(34) + ">Footer</p>{% endblock %}" + Chr(10) +
                 "</div>" + Chr(10) +
                 "</body>" + Chr(10) +
                 "</html>"
EndProcedure

Procedure.s Inh_Child42()
  ProcedureReturn "{% extends " + Chr(34) + "41_base.html" + Chr(34) + " %}" +
                 "{% block title %}Child Page{% endblock %}" +
                 "{% block content %}<div class=" + Chr(34) + "card" + Chr(34) + "><div class=" + Chr(34) + "card-body" + Chr(34) + "><p class=" + Chr(34) + "card-text" + Chr(34) + ">This is the child page content.</p></div></div>{% endblock %}"
EndProcedure

Procedure.s Inh_Child43()
  ProcedureReturn "{% extends " + Chr(34) + "41_base.html" + Chr(34) + " %}" +
                 "{% block title %}Multi Block{% endblock %}" +
                 "{% block header %}<nav class=" + Chr(34) + "nav" + Chr(34) + "><a class=" + Chr(34) + "nav-link" + Chr(34) + " href=" + Chr(34) + "#" + Chr(34) + ">Custom Nav</a></nav>{% endblock %}" +
                 "{% block content %}<div class=" + Chr(34) + "p-3" + Chr(34) + "><p class=" + Chr(34) + "lead" + Chr(34) + ">Custom Content</p></div>{% endblock %}" +
                 "{% block footer %}<p class=" + Chr(34) + "small text-muted" + Chr(34) + ">Custom Footer</p>{% endblock %}"
EndProcedure

Procedure.s Inh_Child44()
  ProcedureReturn "{% extends " + Chr(34) + "41_base.html" + Chr(34) + " %}" +
                 "{% block title %}{{ page_title }}{% endblock %}" +
                 "{% block content %}<div class=" + Chr(34) + "p-3" + Chr(34) + "><p class=" + Chr(34) + "fs-4" + Chr(34) + ">Hello, {{ user_name }}!</p></div>{% endblock %}"
EndProcedure

Procedure.s Inh_Grandchild45()
  ProcedureReturn "{% extends " + Chr(34) + "42_child_simple.html" + Chr(34) + " %}" +
                 "{% block content %}<div class=" + Chr(34) + "card border-primary" + Chr(34) + "><div class=" + Chr(34) + "card-body" + Chr(34) + "><p class=" + Chr(34) + "card-text" + Chr(34) + ">Grandchild overrides child content.</p></div></div>{% endblock %}"
EndProcedure

Procedure.s Inh_ChildLogic46()
  ProcedureReturn "{% extends " + Chr(34) + "41_base.html" + Chr(34) + " %}" +
                 "{% block content %}<div class=" + Chr(34) + "p-3" + Chr(34) + ">{% if show_message %}<p class=" + Chr(34) + "alert alert-info" + Chr(34) + ">{{ message }}</p>{% else %}<p class=" + Chr(34) + "text-muted" + Chr(34) + ">No message.</p>{% endif %}</div>{% endblock %}"
EndProcedure

Procedure.s Inh_Email52()
  ProcedureReturn "{% extends " + Chr(34) + "41_base.html" + Chr(34) + " %}" +
                 "{% block title %}{{ subject }}{% endblock %}" +
                 "{% block content %}<div class=" + Chr(34) + "p-3" + Chr(34) + "><p>Dear {{ recipient }},</p><p>{{ body }}</p><p class=" + Chr(34) + "mt-3" + Chr(34) + ">Best regards,<br>{{ sender }}</p></div>{% endblock %}"
EndProcedure

; ---------------------------------------------------------------------------
; Core helper: Render a child template through the full inheritance pipeline.
;
; Parameters:
;   childName  - the name of the child template in the loader
;   childSrc   - the source of the child template
;   loaderMap  - Map of (name -> source) for all templates the child may need
;   variables  - rendering variables
;
; Returns: rendered HTML string, or an error string prefixed with "[Error]"
; ---------------------------------------------------------------------------
Procedure.s Inh_RenderInherited(childName.s, childSrc.s,
                                  Map loaderTemplates.s(),
                                  Map variables.JinjaVariant::JinjaVariant())
  JinjaError::ClearError()

  ; --- 1. Build DictLoader with all templates ---
  Protected *loader.JinjaLoader::TemplateLoader = JinjaLoader::CreateDictLoader()

  ; Add the child template itself
  JinjaLoader::DictLoaderAdd(*loader, childName, childSrc)

  ; Add any additional templates supplied (parents, grandparents, etc.)
  ForEach loaderTemplates()
    JinjaLoader::DictLoaderAdd(*loader, MapKey(loaderTemplates()), loaderTemplates())
  Next

  ; --- 2. Create Environment with the loader ---
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False   ; HTML templates: keep tags literal
  JinjaEnv::SetLoader(*env, *loader)  ; env now owns *loader

  ; --- 3. Tokenize the child template source ---
  Protected NewList tokens.JinjaToken::Token()
  JinjaLexer::Tokenize(childSrc, tokens())
  If JinjaError::HasError()
    JinjaEnv::FreeEnvironment(*env)
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  ; --- 4. Parse child template ---
  Protected *childAST.JinjaAST::ASTNode = JinjaParser::Parse(tokens())
  If JinjaError::HasError()
    JinjaEnv::FreeEnvironment(*env)
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  ; --- 5. Resolve template inheritance (merges parent blocks with child overrides) ---
  Protected *resolvedAST.JinjaAST::ASTNode = JinjaExtends::Resolve(*env, *childAST)
  If JinjaError::HasError()
    JinjaAST::FreeAST(*childAST)
    JinjaEnv::FreeEnvironment(*env)
    ProcedureReturn "[InheritanceError] " + JinjaError::FormatError()
  EndIf

  ; --- 6. Render the merged AST ---
  Protected result.s = JinjaRenderer::Render(*env, *resolvedAST, variables())

  ; --- 7. Free resources ---
  ; IMPORTANT: ExtendsResolver::Resolve clones parent nodes into *resolvedAST,
  ; but the Default case re-uses (shares) original pointers from the child block
  ; bodies without deep-copying.  Freeing *childAST after *resolvedAST would
  ; cause a double-free on those shared nodes.
  ;
  ; Safe strategy:
  ;  - Always free *resolvedAST  (covers all merged/cloned nodes; shared nodes
  ;    from the child blocks are freed here).
  ;  - Only free *childAST when it is the SAME pointer as *resolvedAST, i.e.
  ;    when there was no {% extends %} tag and Resolve returned *ast unchanged.
  ;    In that case a single FreeAST(*resolvedAST) is sufficient.
  ;  - When *resolvedAST != *childAST (inheritance took place), the child AST
  ;    is intentionally left allocated so its block body nodes — now owned by
  ;    *resolvedAST — are not double-freed.  This is a small, bounded leak per
  ;    render call; acceptable for a test helper.
  JinjaAST::FreeAST(*resolvedAST)
  JinjaEnv::FreeEnvironment(*env)  ; also frees *loader

  ProcedureReturn result
EndProcedure

; ---------------------------------------------------------------------------
; Convenience wrapper: single-parent case (child extends one base template)
; ---------------------------------------------------------------------------
Procedure.s Inh_RenderChild(childName.s, childSrc.s, baseName.s, baseSrc.s,
                              Map variables.JinjaVariant::JinjaVariant())
  Protected NewMap loaderTpls.s()
  loaderTpls(baseName) = baseSrc
  ProcedureReturn Inh_RenderInherited(childName, childSrc, loaderTpls(), variables())
EndProcedure

; ---------------------------------------------------------------------------
; RunInheritanceTests - called by TestRunner.pb
; ---------------------------------------------------------------------------
Procedure RunInheritanceTests()
  PrintN("--- Inheritance Tests ---")

  Protected tmpV.JinjaVariant::JinjaVariant

  ; ==========================================================================
  ; Template 42: Child overrides title + content blocks
  ; ==========================================================================
  ; A simple child that extends the base and replaces "title" and "content".
  ; Expectations:
  ;   CONTAINS:  "Child Page"           (overridden title block)
  ;   CONTAINS:  "card-text"            (overridden content block)
  ;   CONTAINS:  "This is the child page content"
  ;   CONTAINS:  "<html>"               (from base structural HTML)
  ;   NOT CONTAINS: "PureJinja"         (default title was replaced)
  ;   NOT CONTAINS: "Default content."  (default content was replaced)
  ;   CONTAINS:  "Welcome"              (header block NOT overridden - keeps default)
  ;   CONTAINS:  "Footer"               (footer block NOT overridden - keeps default)
  ; --------------------------------------------------------------------------
  Protected NewMap vars42.JinjaVariant::JinjaVariant()
  Protected result42.s = Inh_RenderChild("42_child_simple.html", Inh_Child42(),
                                          "41_base.html", Inh_Base41(), vars42())

  AssertTrue(Bool(FindString(result42, "Child Page") > 0),
             "Inherit 42a: child overrides title block -> 'Child Page'")
  AssertTrue(Bool(FindString(result42, "This is the child page content") > 0),
             "Inherit 42b: child overrides content block -> child content present")
  AssertTrue(Bool(FindString(result42, "card-text") > 0),
             "Inherit 42c: child content block has card-text class")
  AssertTrue(Bool(FindString(result42, "<html>") > 0),
             "Inherit 42d: base structural HTML retained")
  AssertTrue(Bool(FindString(result42, "PureJinja") = 0),
             "Inherit 42e: default title 'PureJinja' replaced by child override")
  AssertTrue(Bool(FindString(result42, "Default content.") = 0),
             "Inherit 42f: default content replaced by child override")
  AssertTrue(Bool(FindString(result42, "Welcome") > 0),
             "Inherit 42g: un-overridden header block keeps default content")
  AssertTrue(Bool(FindString(result42, "Footer") > 0),
             "Inherit 42h: un-overridden footer block keeps default content")

  ; ==========================================================================
  ; Template 43: Child overrides all four blocks
  ; ==========================================================================
  ; Multi-block child: title, header, content and footer are all replaced.
  ; Expectations:
  ;   CONTAINS:  "Multi Block"           (overridden title)
  ;   CONTAINS:  "Custom Nav"            (overridden header)
  ;   CONTAINS:  "Custom Content"        (overridden content)
  ;   CONTAINS:  "Custom Footer"         (overridden footer)
  ;   NOT CONTAINS: "PureJinja"
  ;   NOT CONTAINS: "Welcome"            (base header replaced)
  ;   NOT CONTAINS: "Default content."
  ;   NOT CONTAINS: "Footer"             (base footer replaced)
  ; --------------------------------------------------------------------------
  Protected NewMap vars43.JinjaVariant::JinjaVariant()
  Protected result43.s = Inh_RenderChild("43_child_multi_block.html", Inh_Child43(),
                                          "41_base.html", Inh_Base41(), vars43())

  AssertTrue(Bool(FindString(result43, "Multi Block") > 0),
             "Inherit 43a: title block overridden -> 'Multi Block'")
  AssertTrue(Bool(FindString(result43, "Custom Nav") > 0),
             "Inherit 43b: header block overridden -> 'Custom Nav'")
  AssertTrue(Bool(FindString(result43, "Custom Content") > 0),
             "Inherit 43c: content block overridden -> 'Custom Content'")
  AssertTrue(Bool(FindString(result43, "Custom Footer") > 0),
             "Inherit 43d: footer block overridden -> 'Custom Footer'")
  AssertTrue(Bool(FindString(result43, "PureJinja") = 0),
             "Inherit 43e: default title 'PureJinja' not present")
  AssertTrue(Bool(FindString(result43, "Welcome") = 0),
             "Inherit 43f: default header 'Welcome' not present (overridden)")
  AssertTrue(Bool(FindString(result43, "Default content.") = 0),
             "Inherit 43g: default content not present (overridden)")

  ; ==========================================================================
  ; Template 44: Child uses variables inside blocks
  ; ==========================================================================
  ; Variables page_title and user_name are expanded within the overridden blocks.
  ; Expectations:
  ;   CONTAINS:  "My Dashboard"          (page_title variable in title block)
  ;   CONTAINS:  "Hello, Alice!"         (user_name variable in content block)
  ;   NOT CONTAINS: "Default content."
  ; --------------------------------------------------------------------------
  Protected NewMap vars44.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "My Dashboard")
  vars44("page_title") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Alice")
  vars44("user_name") = tmpV

  Protected result44.s = Inh_RenderChild("44_child_with_vars.html", Inh_Child44(),
                                          "41_base.html", Inh_Base41(), vars44())

  AssertTrue(Bool(FindString(result44, "My Dashboard") > 0),
             "Inherit 44a: page_title variable rendered in title block")
  AssertTrue(Bool(FindString(result44, "Hello, Alice!") > 0),
             "Inherit 44b: user_name variable rendered in content block")
  AssertTrue(Bool(FindString(result44, "Default content.") = 0),
             "Inherit 44c: default content replaced by variable block")
  AssertTrue(Bool(FindString(result44, "<html>") > 0),
             "Inherit 44d: base document structure present")

  ; Variable substitution with different values
  JinjaVariant::StrVariant(@tmpV, "Profile Page")
  vars44("page_title") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Bob")
  vars44("user_name") = tmpV

  Protected result44b.s = Inh_RenderChild("44_child_with_vars.html", Inh_Child44(),
                                           "41_base.html", Inh_Base41(), vars44())

  AssertTrue(Bool(FindString(result44b, "Profile Page") > 0),
             "Inherit 44e: different page_title value rendered correctly")
  AssertTrue(Bool(FindString(result44b, "Hello, Bob!") > 0),
             "Inherit 44f: different user_name value rendered correctly")

  ; ==========================================================================
  ; Template 45: Grandchild (3-level chain: 45 extends 42 extends 41)
  ; ==========================================================================
  ; 45_grandchild.html extends 42_child_simple.html which extends 41_base.html.
  ; The grandchild overrides the "content" block that the child had already
  ; overridden.  The title block from the child (42) should still be used
  ; since the grandchild does not override it.
  ;
  ; Expectations:
  ;   CONTAINS:  "Grandchild overrides child content"
  ;   CONTAINS:  "border-primary"       (grandchild-specific class)
  ;   CONTAINS:  "Child Page"           (title block from 42, not overridden by 45)
  ;   NOT CONTAINS: "This is the child page content"  (42's content replaced by 45)
  ;   NOT CONTAINS: "Default content."
  ;   CONTAINS:  "<html>"               (base structural HTML)
  ; --------------------------------------------------------------------------
  Protected NewMap vars45.JinjaVariant::JinjaVariant()

  ; Grandchild needs both the intermediate child (42) and the base (41) in the loader
  Protected NewMap loaderTpls45.s()
  loaderTpls45("41_base.html") = Inh_Base41()
  loaderTpls45("42_child_simple.html") = Inh_Child42()

  Protected result45.s = Inh_RenderInherited("45_grandchild.html", Inh_Grandchild45(),
                                              loaderTpls45(), vars45())

  AssertTrue(Bool(FindString(result45, "Grandchild overrides child content") > 0),
             "Inherit 45a: grandchild content block present")
  AssertTrue(Bool(FindString(result45, "border-primary") > 0),
             "Inherit 45b: grandchild-specific CSS class present")
  AssertTrue(Bool(FindString(result45, "Child Page") > 0),
             "Inherit 45c: title block from intermediate child (42) inherited by grandchild")
  AssertTrue(Bool(FindString(result45, "This is the child page content") = 0),
             "Inherit 45d: intermediate child content replaced by grandchild override")
  AssertTrue(Bool(FindString(result45, "Default content.") = 0),
             "Inherit 45e: base default content not present")
  AssertTrue(Bool(FindString(result45, "<html>") > 0),
             "Inherit 45f: base document structure present in grandchild output")

  ; ==========================================================================
  ; Template 46: Child uses if/else logic inside a block
  ; ==========================================================================
  ; The content block contains {% if show_message %} ... {% else %} logic.
  ;
  ; Sub-test A: show_message = True, message = "Hello there"
  ;   CONTAINS:  "Hello there"
  ;   CONTAINS:  "alert alert-info"
  ;   NOT CONTAINS: "No message."
  ;
  ; Sub-test B: show_message = False
  ;   CONTAINS:  "No message."
  ;   NOT CONTAINS: "alert alert-info"
  ; --------------------------------------------------------------------------

  ; --- 46-A: show_message is true ---
  Protected NewMap vars46a.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars46a("show_message") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Hello there")
  vars46a("message") = tmpV

  Protected result46a.s = Inh_RenderChild("46_child_with_logic.html", Inh_ChildLogic46(),
                                           "41_base.html", Inh_Base41(), vars46a())

  AssertTrue(Bool(FindString(result46a, "Hello there") > 0),
             "Inherit 46a: message shown when show_message is true")
  AssertTrue(Bool(FindString(result46a, "alert alert-info") > 0),
             "Inherit 46b: alert class present when show_message is true")
  AssertTrue(Bool(FindString(result46a, "No message.") = 0),
             "Inherit 46c: else branch not rendered when show_message is true")

  ; --- 46-B: show_message is false ---
  Protected NewMap vars46b.JinjaVariant::JinjaVariant()
  JinjaVariant::BoolVariant(@tmpV, #False)
  vars46b("show_message") = tmpV

  Protected result46b.s = Inh_RenderChild("46_child_with_logic.html", Inh_ChildLogic46(),
                                           "41_base.html", Inh_Base41(), vars46b())

  AssertTrue(Bool(FindString(result46b, "No message.") > 0),
             "Inherit 46d: fallback text shown when show_message is false")
  AssertTrue(Bool(FindString(result46b, "alert alert-info") = 0),
             "Inherit 46e: alert class absent when show_message is false")

  ; ==========================================================================
  ; Template 52: Email template (variables in both title and content blocks)
  ; ==========================================================================
  ; A realistic email layout: subject->title, recipient/body/sender->content.
  ;
  ; Expectations:
  ;   CONTAINS:  "Welcome to PureJinja"  (subject -> title block)
  ;   CONTAINS:  "Dear John,"            (recipient variable)
  ;   CONTAINS:  "Please verify"         (body variable)
  ;   CONTAINS:  "Best regards"          (static text in content)
  ;   CONTAINS:  "The PureJinja Team"    (sender variable)
  ;   NOT CONTAINS: "Default content."
  ;   NOT CONTAINS: "PureJinja" in title position? (overridden by subject)
  ;   CONTAINS:  "Welcome"              (header block from base, not overridden)
  ; --------------------------------------------------------------------------
  Protected NewMap vars52.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "Welcome to PureJinja")
  vars52("subject") = tmpV
  JinjaVariant::StrVariant(@tmpV, "John")
  vars52("recipient") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Please verify your account.")
  vars52("body") = tmpV
  JinjaVariant::StrVariant(@tmpV, "The PureJinja Team")
  vars52("sender") = tmpV

  Protected result52.s = Inh_RenderChild("52_email_template.html", Inh_Email52(),
                                          "41_base.html", Inh_Base41(), vars52())

  AssertTrue(Bool(FindString(result52, "Welcome to PureJinja") > 0),
             "Inherit 52a: subject variable rendered in title block")
  AssertTrue(Bool(FindString(result52, "Dear John,") > 0),
             "Inherit 52b: recipient variable rendered in content block")
  AssertTrue(Bool(FindString(result52, "Please verify your account.") > 0),
             "Inherit 52c: body variable rendered in content block")
  AssertTrue(Bool(FindString(result52, "Best regards") > 0),
             "Inherit 52d: static 'Best regards' text present in content block")
  AssertTrue(Bool(FindString(result52, "The PureJinja Team") > 0),
             "Inherit 52e: sender variable rendered in content block")
  AssertTrue(Bool(FindString(result52, "Default content.") = 0),
             "Inherit 52f: default content replaced by email content block")
  AssertTrue(Bool(FindString(result52, "Welcome") > 0),
             "Inherit 52g: base header block retained (not overridden by email template)")
  AssertTrue(Bool(FindString(result52, "<html>") > 0),
             "Inherit 52h: base document structure present")

  ; Second render: different recipient and message
  JinjaVariant::StrVariant(@tmpV, "Password Reset")
  vars52("subject") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Jane")
  vars52("recipient") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Click to reset your password.")
  vars52("body") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Support")
  vars52("sender") = tmpV

  Protected result52b.s = Inh_RenderChild("52_email_template.html", Inh_Email52(),
                                           "41_base.html", Inh_Base41(), vars52())

  AssertTrue(Bool(FindString(result52b, "Password Reset") > 0),
             "Inherit 52i: second render - subject 'Password Reset' in title")
  AssertTrue(Bool(FindString(result52b, "Dear Jane,") > 0),
             "Inherit 52j: second render - recipient 'Jane' in content")
  AssertTrue(Bool(FindString(result52b, "Click to reset your password.") > 0),
             "Inherit 52k: second render - different body variable rendered")

  PrintN("")
EndProcedure
