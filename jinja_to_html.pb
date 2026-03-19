; jinja_to_html.pb
; Renders all 55 PureJinja demo templates to static HTML files.
;
; Compile (macOS/Linux): pbcompiler -cl jinja_to_html.pb -o jinja_to_html_app
; Compile (Windows):     pbcompiler /cl jinja_to_html.pb /exe jinja_to_html_app.exe
; Run (macOS/Linux):     ./jinja_to_html_app
; Run (Windows):         jinja_to_html_app.exe

XIncludeFile "PureJinja.pbi"

#OutputDir = "jinja_to_html/"

;-- Helper: set a string variable in the vars map
Procedure SetStr(Map vars.JinjaVariant::JinjaVariant(), key.s, value.s)
  Protected v.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@v, value)
  vars(key) = v
EndProcedure

;-- Helper: set an integer variable
Procedure SetInt(Map vars.JinjaVariant::JinjaVariant(), key.s, value.q)
  Protected v.JinjaVariant::JinjaVariant
  JinjaVariant::IntVariant(@v, value)
  vars(key) = v
EndProcedure

;-- Helper: set a boolean variable
Procedure SetBool(Map vars.JinjaVariant::JinjaVariant(), key.s, value.i)
  Protected v.JinjaVariant::JinjaVariant
  JinjaVariant::BoolVariant(@v, value)
  vars(key) = v
EndProcedure

;-- Helper: set a markup (safe HTML) variable
Procedure SetMarkup(Map vars.JinjaVariant::JinjaVariant(), key.s, value.s)
  Protected v.JinjaVariant::JinjaVariant
  JinjaVariant::MarkupVariant(@v, value)
  vars(key) = v
EndProcedure

;-- Helper: free all variants in the map and clear it
Procedure CleanupVars(Map vars.JinjaVariant::JinjaVariant())
  ForEach vars()
    JinjaVariant::FreeVariant(@vars())
  Next
  ClearMap(vars())
EndProcedure

;-- Helper: render a template and save the result to a file
Procedure.i RenderAndSave(*env, templateName.s, Map vars.JinjaVariant::JinjaVariant(), outputDir.s)
  Protected result.s = JinjaEnv::RenderTemplate(*env, templateName, vars())
  Protected outputPath.s = outputDir + templateName
  Protected file.i = CreateFile(#PB_Any, outputPath, #PB_UTF8)
  If file
    WriteString(file, result, #PB_UTF8)
    CloseFile(file)
    PrintN("[OK]  " + templateName)
    ProcedureReturn 1
  Else
    PrintN("[ERR] " + templateName + " (write failed)")
    ProcedureReturn 0
  EndIf
EndProcedure

;-- Helper: create a string list variant and assign to vars map
Procedure MakeStringList(Map vars.JinjaVariant::JinjaVariant(), key.s, Array items.s(1))
  Protected listV.JinjaVariant::JinjaVariant
  Protected tmpV.JinjaVariant::JinjaVariant
  Protected i.i
  JinjaVariant::NewListVariant(@listV)
  For i = 0 To ArraySize(items())
    JinjaVariant::StrVariant(@tmpV, items(i))
    JinjaVariant::VListAdd(@listV, @tmpV)
  Next
  vars(key) = listV
EndProcedure

; ============================================================
; Main program
; ============================================================

OpenConsole()
PrintN("PureJinja -> HTML renderer")
PrintN("==========================")
PrintN("")

Define *env = JinjaEnv::CreateEnvironment()
JinjaEnv::SetTemplatePath(*env, "templates/")

CreateDirectory(#OutputDir)

Define NewMap vars.JinjaVariant::JinjaVariant()
Define ok.i = 0
Define tmpV.JinjaVariant::JinjaVariant
Define listV.JinjaVariant::JinjaVariant
Define mapV.JinjaVariant::JinjaVariant
Define mapV2.JinjaVariant::JinjaVariant
Define innerList.JinjaVariant::JinjaVariant

; ----------------------------------------------------------
; 01 - Hello
; ----------------------------------------------------------
SetStr(vars(), "name", "World")
ok + RenderAndSave(*env, "01_hello.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 02 - Multiple variables
; ----------------------------------------------------------
SetStr(vars(), "first", "John")
SetStr(vars(), "last", "Doe")
ok + RenderAndSave(*env, "02_multiple_vars.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 03 - Missing variable (no vars needed)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "03_missing_var.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 04 - Integer variable
; ----------------------------------------------------------
SetInt(vars(), "count", 42)
ok + RenderAndSave(*env, "04_integer_var.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 05 - Nested access (user map)
; ----------------------------------------------------------
JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Alice")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::StrVariant(@tmpV, "alice@example.com")
JinjaVariant::VMapSet(@mapV, "email", @tmpV)
vars("user") = mapV
ok + RenderAndSave(*env, "05_nested_access.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 06 - Upper filter
; ----------------------------------------------------------
SetStr(vars(), "name", "hello world")
ok + RenderAndSave(*env, "06_upper.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 07 - Lower filter
; ----------------------------------------------------------
SetStr(vars(), "NAME", "HELLO WORLD")
ok + RenderAndSave(*env, "07_lower.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 08 - Title filter
; ----------------------------------------------------------
SetStr(vars(), "text", "hello world")
ok + RenderAndSave(*env, "08_title.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 09 - Capitalize filter
; ----------------------------------------------------------
SetStr(vars(), "text", "hello world")
ok + RenderAndSave(*env, "09_capitalize.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 10 - Trim filter
; ----------------------------------------------------------
SetStr(vars(), "text", "  hello  ")
ok + RenderAndSave(*env, "10_trim.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 11 - Length filter
; ----------------------------------------------------------
SetStr(vars(), "text", "hello")
ok + RenderAndSave(*env, "11_length.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 12 - Default filter (no vars — uses |default)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "12_default.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 13 - Replace filter
; ----------------------------------------------------------
SetStr(vars(), "text", "hello world")
ok + RenderAndSave(*env, "13_replace.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 14 - First / Last filter
; ----------------------------------------------------------
SetStr(vars(), "text", "hello")
ok + RenderAndSave(*env, "14_first_last.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 15 - Chained filters
; ----------------------------------------------------------
SetStr(vars(), "name", "  hello  ")
ok + RenderAndSave(*env, "15_chained.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 16 - If true
; ----------------------------------------------------------
SetBool(vars(), "logged_in", #True)
ok + RenderAndSave(*env, "16_if_true.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 17 - If not
; ----------------------------------------------------------
SetBool(vars(), "logged_in", #False)
ok + RenderAndSave(*env, "17_if_not.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 18 - If else
; ----------------------------------------------------------
SetBool(vars(), "logged_in", #True)
ok + RenderAndSave(*env, "18_if_else.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 19 - If elif
; ----------------------------------------------------------
SetStr(vars(), "role", "admin")
ok + RenderAndSave(*env, "19_if_elif.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 20 - If comparison
; ----------------------------------------------------------
SetInt(vars(), "age", 21)
ok + RenderAndSave(*env, "20_if_comparison.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 21 - If in (list of roles)
; ----------------------------------------------------------
Dim roles.s(1)
roles(0) = "admin"
roles(1) = "user"
MakeStringList(vars(), "roles", roles())
ok + RenderAndSave(*env, "21_if_in.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 22 - If and/or
; ----------------------------------------------------------
SetBool(vars(), "is_active", #True)
SetBool(vars(), "is_verified", #True)
ok + RenderAndSave(*env, "22_if_and_or.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 23 - For simple
; ----------------------------------------------------------
Dim items3.s(2)
items3(0) = "Apple" : items3(1) = "Banana" : items3(2) = "Cherry"
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "23_for_simple.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 24 - For index
; ----------------------------------------------------------
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "24_for_index.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 25 - For first/last
; ----------------------------------------------------------
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "25_for_first_last.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 26 - For dict (list of user maps)
; ----------------------------------------------------------
JinjaVariant::NewListVariant(@listV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Alice")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::StrVariant(@tmpV, "admin")
JinjaVariant::VMapSet(@mapV, "role", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Bob")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::StrVariant(@tmpV, "user")
JinjaVariant::VMapSet(@mapV, "role", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

vars("users") = listV
ok + RenderAndSave(*env, "26_for_dict.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 27 - For else (non-empty list shows loop body)
; ----------------------------------------------------------
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "27_for_else.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 28 - For nested (list of lists)
; ----------------------------------------------------------
JinjaVariant::NewListVariant(@listV)

JinjaVariant::NewListVariant(@innerList)
JinjaVariant::StrVariant(@tmpV, "a")
JinjaVariant::VListAdd(@innerList, @tmpV)
JinjaVariant::StrVariant(@tmpV, "b")
JinjaVariant::VListAdd(@innerList, @tmpV)
JinjaVariant::VListAdd(@listV, @innerList)

JinjaVariant::NewListVariant(@innerList)
JinjaVariant::StrVariant(@tmpV, "c")
JinjaVariant::VListAdd(@innerList, @tmpV)
JinjaVariant::StrVariant(@tmpV, "d")
JinjaVariant::VListAdd(@innerList, @tmpV)
JinjaVariant::VListAdd(@listV, @innerList)

vars("groups") = listV
ok + RenderAndSave(*env, "28_for_nested.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 29 - For filter
; ----------------------------------------------------------
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "29_for_filter.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 30 - For conditional
; ----------------------------------------------------------
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "30_for_conditional.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 31 - For counter
; ----------------------------------------------------------
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "31_for_counter.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 32 - For set
; ----------------------------------------------------------
MakeStringList(vars(), "items", items3())
ok + RenderAndSave(*env, "32_for_set.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 33 - Set variable (no vars — uses {% set %} internally)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "33_set_variable.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 34 - Set computed
; ----------------------------------------------------------
SetInt(vars(), "price", 10)
SetInt(vars(), "quantity", 5)
ok + RenderAndSave(*env, "34_set_computed.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 35 - Set in scope (no vars — uses {% set %} internally)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "35_set_in_scope.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 36 - Escape HTML (autoescape handles it)
; ----------------------------------------------------------
SetStr(vars(), "user_input", "<script>alert('xss')</script>")
ok + RenderAndSave(*env, "36_escape_html.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 37 - Safe markup (MarkupVariant bypasses escaping)
; ----------------------------------------------------------
SetMarkup(vars(), "safe_html", "<b>Bold</b>")
ok + RenderAndSave(*env, "37_safe_markup.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 38 - Escape attributes
; ----------------------------------------------------------
SetStr(vars(), "url", "https://example.com?a=1&b=2")
SetStr(vars(), "link_text", "Click & Go")
ok + RenderAndSave(*env, "38_escape_attributes.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 39 - Double escape prevention
; ----------------------------------------------------------
SetStr(vars(), "already_escaped", "&lt;b&gt;safe&lt;/b&gt;")
ok + RenderAndSave(*env, "39_double_escape_prevention.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 40 - Mixed safe/unsafe
; ----------------------------------------------------------
SetMarkup(vars(), "safe_part", "<b>Bold</b>")
SetStr(vars(), "unsafe_part", "<script>bad</script>")
ok + RenderAndSave(*env, "40_mixed_safe_unsafe.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 41 - Base template (rendered standalone with default blocks)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "41_base.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 42 - Child simple (extends 41, no vars)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "42_child_simple.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 43 - Child multi block (extends 41, no vars)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "43_child_multi_block.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 44 - Child with vars (extends 41)
; ----------------------------------------------------------
SetStr(vars(), "page_title", "Welcome")
SetStr(vars(), "user_name", "Alice")
ok + RenderAndSave(*env, "44_child_with_vars.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 45 - Grandchild (extends 42 -> 41, no vars)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "45_grandchild.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 46 - Child with logic (extends 41)
; ----------------------------------------------------------
SetBool(vars(), "show_message", #True)
SetStr(vars(), "message", "Hello from child!")
ok + RenderAndSave(*env, "46_child_with_logic.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 47 - Header partial (standalone partial)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "47_header_partial.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 48 - Include header (includes 47, no vars)
; ----------------------------------------------------------
ok + RenderAndSave(*env, "48_include_header.html", vars(), #OutputDir)

; ----------------------------------------------------------
; 49 - Include with context
; ----------------------------------------------------------
SetStr(vars(), "name", "World")
ok + RenderAndSave(*env, "49_include_with_context.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 50 - Product list (list of product maps)
; ----------------------------------------------------------
JinjaVariant::NewListVariant(@listV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Widget")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::IntVariant(@tmpV, 10)
JinjaVariant::VMapSet(@mapV, "price", @tmpV)
JinjaVariant::BoolVariant(@tmpV, #True)
JinjaVariant::VMapSet(@mapV, "in_stock", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Gadget")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::IntVariant(@tmpV, 25)
JinjaVariant::VMapSet(@mapV, "price", @tmpV)
JinjaVariant::BoolVariant(@tmpV, #False)
JinjaVariant::VMapSet(@mapV, "in_stock", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

vars("products") = listV
ok + RenderAndSave(*env, "50_product_list.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 51 - User profile (user map with optional bio)
; ----------------------------------------------------------
JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Alice")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::StrVariant(@tmpV, "alice@example.com")
JinjaVariant::VMapSet(@mapV, "email", @tmpV)
JinjaVariant::StrVariant(@tmpV, "Developer")
JinjaVariant::VMapSet(@mapV, "bio", @tmpV)
vars("user") = mapV
ok + RenderAndSave(*env, "51_user_profile.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 52 - Email template (extends 41)
; ----------------------------------------------------------
SetStr(vars(), "subject", "Welcome")
SetStr(vars(), "recipient", "Alice")
SetStr(vars(), "body", "Thanks for joining!")
SetStr(vars(), "sender", "Team")
ok + RenderAndSave(*env, "52_email_template.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 53 - Table report (list of row maps)
; ----------------------------------------------------------
JinjaVariant::NewListVariant(@listV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Alpha")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::StrVariant(@tmpV, "100")
JinjaVariant::VMapSet(@mapV, "value", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "Beta")
JinjaVariant::VMapSet(@mapV, "name", @tmpV)
JinjaVariant::StrVariant(@tmpV, "200")
JinjaVariant::VMapSet(@mapV, "value", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

vars("rows") = listV
ok + RenderAndSave(*env, "53_table_report.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 54 - Navigation (list of link maps + active_url)
; ----------------------------------------------------------
JinjaVariant::NewListVariant(@listV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "/home")
JinjaVariant::VMapSet(@mapV, "url", @tmpV)
JinjaVariant::StrVariant(@tmpV, "Home")
JinjaVariant::VMapSet(@mapV, "label", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

JinjaVariant::NewMapVariant(@mapV)
JinjaVariant::StrVariant(@tmpV, "/about")
JinjaVariant::VMapSet(@mapV, "url", @tmpV)
JinjaVariant::StrVariant(@tmpV, "About")
JinjaVariant::VMapSet(@mapV, "label", @tmpV)
JinjaVariant::VListAdd(@listV, @mapV)

vars("links") = listV
SetStr(vars(), "active_url", "/home")
ok + RenderAndSave(*env, "54_navigation.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; 55 - Error page
; ----------------------------------------------------------
SetInt(vars(), "error_code", 404)
SetStr(vars(), "error_message", "Page not found")
SetBool(vars(), "show_details", #True)
SetStr(vars(), "error_details", "The requested URL was not found on this server.")
ok + RenderAndSave(*env, "55_error_page.html", vars(), #OutputDir)
CleanupVars(vars())

; ----------------------------------------------------------
; Summary
; ----------------------------------------------------------
PrintN("")
PrintN("Rendered: " + Str(ok) + "/55")

JinjaEnv::FreeEnvironment(*env)
CloseConsole()
