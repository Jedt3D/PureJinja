; ============================================================================
; PureJinja - TestRealWorld.pbi
; Real-world acceptance tests: include (47-49) and complex templates (50-55)
; Uses Rw_ prefix for helpers to avoid naming conflicts.
; ============================================================================
EnableExplicit

; ---------------------------------------------------------------------------
; Helper: Render a string template with autoescape OFF
; ---------------------------------------------------------------------------
Procedure.s Rw_RenderStr(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False
  Protected result.s = JinjaEnv::RenderString(*env, templateStr, variables())
  JinjaEnv::FreeEnvironment(*env)
  ProcedureReturn result
EndProcedure

; ---------------------------------------------------------------------------
; Helper: Render a named template using a DictLoader with multiple templates.
; Pass template sources as two parallel arrays (names + sources, up to 4).
; ---------------------------------------------------------------------------
Procedure.s Rw_RenderWithLoader(mainTemplate.s,
                                 name1.s, src1.s,
                                 name2.s, src2.s,
                                 Map variables.JinjaVariant::JinjaVariant())
  JinjaError::ClearError()

  Protected *loader.JinjaLoader::TemplateLoader = JinjaLoader::CreateDictLoader()
  If name1 <> "" : JinjaLoader::DictLoaderAdd(*loader, name1, src1) : EndIf
  If name2 <> "" : JinjaLoader::DictLoaderAdd(*loader, name2, src2) : EndIf

  Protected *env.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *env\Autoescape = #False
  JinjaEnv::SetLoader(*env, *loader)  ; env takes ownership of loader

  Protected result.s = JinjaEnv::RenderTemplate(*env, mainTemplate, variables())
  JinjaEnv::FreeEnvironment(*env)  ; frees loader too

  ProcedureReturn result
EndProcedure

; ---------------------------------------------------------------------------
; Helper: AssertContains — checks that haystack contains needle
; ---------------------------------------------------------------------------
Procedure Rw_AssertContains(haystack.s, needle.s, testName.s)
  AssertTrue(Bool(FindString(haystack, needle) > 0), testName)
EndProcedure

; ---------------------------------------------------------------------------
; Helper: AssertNotContains — checks that haystack does NOT contain needle
; ---------------------------------------------------------------------------
Procedure Rw_AssertNotContains(haystack.s, needle.s, testName.s)
  AssertTrue(Bool(FindString(haystack, needle) = 0), testName)
EndProcedure


; ============================================================================
Procedure RunRealWorldTests()
  PrintN("--- Real-World Tests ---")

  Protected tmpV.JinjaVariant::JinjaVariant
  Protected itemV.JinjaVariant::JinjaVariant

  ; ==========================================================================
  ; Category: Include (templates 47-49)
  ; ==========================================================================

  ; --- Template sources ---
  Protected tpl47_header.s = "<nav class=" + Chr(34) + "navbar navbar-expand-lg navbar-light bg-light" + Chr(34) + ">" + Chr(10) +
                              "<div class=" + Chr(34) + "container" + Chr(34) + ">" + Chr(10) +
                              "<a class=" + Chr(34) + "nav-link" + Chr(34) + " href=" + Chr(34) + "/" + Chr(34) + ">Home</a>" + Chr(10) +
                              "<a class=" + Chr(34) + "nav-link" + Chr(34) + " href=" + Chr(34) + "/about" + Chr(34) + ">About</a>" + Chr(10) +
                              "</div>" + Chr(10) +
                              "</nav>"

  Protected tpl48_main.s = "<!DOCTYPE html>" + Chr(10) +
                            "<html>" + Chr(10) +
                            "<head><meta charset=" + Chr(34) + "utf-8" + Chr(34) + "><title>Include Test</title></head>" + Chr(10) +
                            "<body>" + Chr(10) +
                            "{% include " + Chr(34) + "47_header_partial.html" + Chr(34) + " %}" + Chr(10) +
                            "<div class=" + Chr(34) + "container py-4" + Chr(34) + ">" + Chr(10) +
                            "<main><p>Page content here.</p></main>" + Chr(10) +
                            "</div>" + Chr(10) +
                            "</body>" + Chr(10) +
                            "</html>"

  Protected tpl49_main.s = "<!DOCTYPE html>" + Chr(10) +
                            "<html>" + Chr(10) +
                            "<head><meta charset=" + Chr(34) + "utf-8" + Chr(34) + "><title>Include with Context</title></head>" + Chr(10) +
                            "<body>" + Chr(10) +
                            "{% include " + Chr(34) + "47_header_partial.html" + Chr(34) + " %}" + Chr(10) +
                            "<div class=" + Chr(34) + "container py-4" + Chr(34) + ">" + Chr(10) +
                            "<p class=" + Chr(34) + "fs-4" + Chr(34) + ">Welcome, {{ name }}!</p>" + Chr(10) +
                            "</div>" + Chr(10) +
                            "</body>" + Chr(10) +
                            "</html>"

  ; --- 47_header_partial.html: static partial (no vars needed) ---
  Protected NewMap vars47.JinjaVariant::JinjaVariant()
  Protected result47.s = Rw_RenderStr(tpl47_header, vars47())
  Rw_AssertContains(result47, "navbar", "Accept 47: header_partial - contains navbar class")
  Rw_AssertContains(result47, "Home</a>", "Accept 47: header_partial - contains Home link")
  Rw_AssertContains(result47, "About</a>", "Accept 47: header_partial - contains About link")
  Rw_AssertContains(result47, "/about", "Accept 47: header_partial - contains /about href")

  ; --- 48_include_header.html: includes 47 ---
  Protected NewMap vars48.JinjaVariant::JinjaVariant()
  Protected result48.s = Rw_RenderWithLoader("48_include_header.html",
                                              "48_include_header.html", tpl48_main,
                                              "47_header_partial.html", tpl47_header,
                                              vars48())
  Rw_AssertContains(result48, "<!DOCTYPE html>", "Accept 48: include_header - DOCTYPE present")
  Rw_AssertContains(result48, "Include Test</title>", "Accept 48: include_header - page title present")
  Rw_AssertContains(result48, "navbar", "Accept 48: include_header - included navbar class")
  Rw_AssertContains(result48, "Home</a>", "Accept 48: include_header - included Home link")
  Rw_AssertContains(result48, "About</a>", "Accept 48: include_header - included About link")
  Rw_AssertContains(result48, "Page content here.", "Accept 48: include_header - page body present")

  ; --- 49_include_with_context.html: includes 47 + uses variable ---
  Protected NewMap vars49.JinjaVariant::JinjaVariant()
  JinjaVariant::StrVariant(@tmpV, "Alice")
  vars49("name") = tmpV
  Protected result49.s = Rw_RenderWithLoader("49_include_with_context.html",
                                              "49_include_with_context.html", tpl49_main,
                                              "47_header_partial.html", tpl47_header,
                                              vars49())
  Rw_AssertContains(result49, "Include with Context</title>", "Accept 49: include_with_context - page title present")
  Rw_AssertContains(result49, "navbar", "Accept 49: include_with_context - included navbar class")
  Rw_AssertContains(result49, "Home</a>", "Accept 49: include_with_context - included Home link")
  Rw_AssertContains(result49, "Welcome, Alice!", "Accept 49: include_with_context - context variable rendered")

  ; ==========================================================================
  ; Category: Real-world templates (50-55, standalone)
  ; ==========================================================================

  ; --- 50_product_list.html: for loop over products, in_stock conditional, for/else ---
  Protected tpl50.s = "{% if products %}{% for product in products %}" +
                       "<div>{{ product.name|upper }} - ${{ product.price }}" +
                       "{% if product.in_stock %} [In Stock]{% else %} [Out of Stock]{% endif %}" +
                       "</div>" +
                       "{% endfor %}{% else %}<p>No products available.</p>{% endif %}"

  ; With products
  Protected productsList50.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@productsList50)

  Protected prod50a.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@prod50a)
  JinjaVariant::StrVariant(@tmpV, "Widget")
  JinjaVariant::VMapSet(@prod50a, "name", @tmpV)
  JinjaVariant::IntVariant(@tmpV, 9)
  JinjaVariant::VMapSet(@prod50a, "price", @tmpV)
  JinjaVariant::BoolVariant(@tmpV, #True)
  JinjaVariant::VMapSet(@prod50a, "in_stock", @tmpV)
  JinjaVariant::VListAdd(@productsList50, @prod50a)
  JinjaVariant::FreeVariant(@prod50a)

  Protected prod50b.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@prod50b)
  JinjaVariant::StrVariant(@tmpV, "Gadget")
  JinjaVariant::VMapSet(@prod50b, "name", @tmpV)
  JinjaVariant::IntVariant(@tmpV, 49)
  JinjaVariant::VMapSet(@prod50b, "price", @tmpV)
  JinjaVariant::BoolVariant(@tmpV, #False)
  JinjaVariant::VMapSet(@prod50b, "in_stock", @tmpV)
  JinjaVariant::VListAdd(@productsList50, @prod50b)
  JinjaVariant::FreeVariant(@prod50b)

  Protected NewMap vars50.JinjaVariant::JinjaVariant()
  vars50("products") = productsList50

  Protected result50.s = Rw_RenderStr(tpl50, vars50())
  Rw_AssertContains(result50, "WIDGET", "Accept 50: product_list - name rendered as upper")
  Rw_AssertContains(result50, "$9", "Accept 50: product_list - price rendered")
  Rw_AssertContains(result50, "[In Stock]", "Accept 50: product_list - in_stock true branch")
  Rw_AssertContains(result50, "GADGET", "Accept 50: product_list - second product name upper")
  Rw_AssertContains(result50, "$49", "Accept 50: product_list - second product price")
  Rw_AssertContains(result50, "[Out of Stock]", "Accept 50: product_list - in_stock false branch")
  Rw_AssertNotContains(result50, "No products available.", "Accept 50: product_list - non-empty hides for/else")

  JinjaVariant::FreeVariant(@productsList50)

  ; Empty product list: for/else renders fallback message
  Protected emptyProducts50.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@emptyProducts50)
  Protected NewMap vars50b.JinjaVariant::JinjaVariant()
  vars50b("products") = emptyProducts50
  Protected result50b.s = Rw_RenderStr(tpl50, vars50b())
  Rw_AssertContains(result50b, "No products available.", "Accept 50: product_list - empty list renders for/else")
  JinjaVariant::FreeVariant(@emptyProducts50)

  ; --- 51_user_profile.html: user.name, user.email, user.bio (if/else for missing bio) ---
  Protected tpl51.s = "<h1>{{ user.name }}</h1>" +
                       "<p>Email: {{ user.email }}</p>" +
                       "{% if user.bio %}<p>Bio: {{ user.bio }}</p>{% else %}<p>No bio provided.</p>{% endif %}"

  ; With bio
  Protected userMap51.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@userMap51)
  JinjaVariant::StrVariant(@tmpV, "Bob Smith")
  JinjaVariant::VMapSet(@userMap51, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "bob@example.com")
  JinjaVariant::VMapSet(@userMap51, "email", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "PureBasic enthusiast and template engine developer.")
  JinjaVariant::VMapSet(@userMap51, "bio", @tmpV)
  Protected NewMap vars51.JinjaVariant::JinjaVariant()
  vars51("user") = userMap51

  Protected result51.s = Rw_RenderStr(tpl51, vars51())
  Rw_AssertContains(result51, "<h1>Bob Smith</h1>", "Accept 51: user_profile - name in heading")
  Rw_AssertContains(result51, "Email: bob@example.com", "Accept 51: user_profile - email rendered")
  Rw_AssertContains(result51, "Bio: PureBasic enthusiast", "Accept 51: user_profile - bio rendered")
  Rw_AssertNotContains(result51, "No bio provided.", "Accept 51: user_profile - bio present hides fallback")

  JinjaVariant::FreeVariant(@userMap51)

  ; Without bio (bio key absent => empty/null)
  Protected userNoBio51.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@userNoBio51)
  JinjaVariant::StrVariant(@tmpV, "Jane Doe")
  JinjaVariant::VMapSet(@userNoBio51, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "jane@example.com")
  JinjaVariant::VMapSet(@userNoBio51, "email", @tmpV)
  ; bio key intentionally omitted
  Protected NewMap vars51b.JinjaVariant::JinjaVariant()
  vars51b("user") = userNoBio51

  Protected result51b.s = Rw_RenderStr(tpl51, vars51b())
  Rw_AssertContains(result51b, "<h1>Jane Doe</h1>", "Accept 51b: user_profile - name without bio")
  Rw_AssertContains(result51b, "No bio provided.", "Accept 51b: user_profile - missing bio renders fallback")
  Rw_AssertNotContains(result51b, "Bio:", "Accept 51b: user_profile - Bio: label absent when no bio")

  JinjaVariant::FreeVariant(@userNoBio51)

  ; --- Template 52 is handled by dev_guy_1 (inheritance test, extends 41_base) ---

  ; --- 53_table_report.html: for loop with loop.index, row.name, row.value ---
  Protected tpl53.s = "<table>" + Chr(10) +
                       "<thead><tr><th>#</th><th>Name</th><th>Value</th></tr></thead>" + Chr(10) +
                       "<tbody>" + Chr(10) +
                       "{% for row in rows %}" +
                       "<tr><td>{{ loop.index }}</td><td>{{ row.name }}</td><td>{{ row.value }}</td></tr>" + Chr(10) +
                       "{% endfor %}" +
                       "</tbody>" + Chr(10) +
                       "</table>"

  Protected rowsList53.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@rowsList53)

  Protected row53a.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@row53a)
  JinjaVariant::StrVariant(@tmpV, "Revenue")
  JinjaVariant::VMapSet(@row53a, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "$10,000")
  JinjaVariant::VMapSet(@row53a, "value", @tmpV)
  JinjaVariant::VListAdd(@rowsList53, @row53a)
  JinjaVariant::FreeVariant(@row53a)

  Protected row53b.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@row53b)
  JinjaVariant::StrVariant(@tmpV, "Expenses")
  JinjaVariant::VMapSet(@row53b, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "$4,500")
  JinjaVariant::VMapSet(@row53b, "value", @tmpV)
  JinjaVariant::VListAdd(@rowsList53, @row53b)
  JinjaVariant::FreeVariant(@row53b)

  Protected row53c.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@row53c)
  JinjaVariant::StrVariant(@tmpV, "Profit")
  JinjaVariant::VMapSet(@row53c, "name", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "$5,500")
  JinjaVariant::VMapSet(@row53c, "value", @tmpV)
  JinjaVariant::VListAdd(@rowsList53, @row53c)
  JinjaVariant::FreeVariant(@row53c)

  Protected NewMap vars53.JinjaVariant::JinjaVariant()
  vars53("rows") = rowsList53

  Protected result53.s = Rw_RenderStr(tpl53, vars53())
  Rw_AssertContains(result53, "<table>", "Accept 53: table_report - table tag present")
  Rw_AssertContains(result53, "<th>Name</th>", "Accept 53: table_report - header Name present")
  Rw_AssertContains(result53, "<td>1</td>", "Accept 53: table_report - loop.index starts at 1")
  Rw_AssertContains(result53, "<td>2</td>", "Accept 53: table_report - loop.index 2 present")
  Rw_AssertContains(result53, "<td>3</td>", "Accept 53: table_report - loop.index 3 present")
  Rw_AssertContains(result53, "Revenue", "Accept 53: table_report - row1 name rendered")
  Rw_AssertContains(result53, "$10,000", "Accept 53: table_report - row1 value rendered")
  Rw_AssertContains(result53, "Expenses", "Accept 53: table_report - row2 name rendered")
  Rw_AssertContains(result53, "Profit", "Accept 53: table_report - row3 name rendered")
  Rw_AssertContains(result53, "$5,500", "Accept 53: table_report - row3 value rendered")

  JinjaVariant::FreeVariant(@rowsList53)

  ; --- 54_navigation.html: for loop with if comparison (link.url == active_url) ---
  Protected tpl54.s = "<nav><ul>" + Chr(10) +
                       "{% for link in links %}" +
                       "<li><a href=" + Chr(34) + "{{ link.url }}" + Chr(34) +
                       "{% if link.url == active_url %} class=" + Chr(34) + "active" + Chr(34) + "{% endif %}" +
                       ">{{ link.label }}</a></li>" + Chr(10) +
                       "{% endfor %}" +
                       "</ul></nav>"

  Protected linksList54.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@linksList54)

  Protected link54a.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@link54a)
  JinjaVariant::StrVariant(@tmpV, "/")
  JinjaVariant::VMapSet(@link54a, "url", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "Home")
  JinjaVariant::VMapSet(@link54a, "label", @tmpV)
  JinjaVariant::VListAdd(@linksList54, @link54a)
  JinjaVariant::FreeVariant(@link54a)

  Protected link54b.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@link54b)
  JinjaVariant::StrVariant(@tmpV, "/about")
  JinjaVariant::VMapSet(@link54b, "url", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "About")
  JinjaVariant::VMapSet(@link54b, "label", @tmpV)
  JinjaVariant::VListAdd(@linksList54, @link54b)
  JinjaVariant::FreeVariant(@link54b)

  Protected link54c.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@link54c)
  JinjaVariant::StrVariant(@tmpV, "/contact")
  JinjaVariant::VMapSet(@link54c, "url", @tmpV)
  JinjaVariant::StrVariant(@tmpV, "Contact")
  JinjaVariant::VMapSet(@link54c, "label", @tmpV)
  JinjaVariant::VListAdd(@linksList54, @link54c)
  JinjaVariant::FreeVariant(@link54c)

  Protected NewMap vars54.JinjaVariant::JinjaVariant()
  vars54("links") = linksList54
  JinjaVariant::StrVariant(@tmpV, "/about")
  vars54("active_url") = tmpV

  Protected result54.s = Rw_RenderStr(tpl54, vars54())
  Rw_AssertContains(result54, "href=" + Chr(34) + "/" + Chr(34), "Accept 54: navigation - home href present")
  Rw_AssertContains(result54, ">Home</a>", "Accept 54: navigation - Home label present")
  Rw_AssertContains(result54, "href=" + Chr(34) + "/about" + Chr(34) + " class=" + Chr(34) + "active" + Chr(34), "Accept 54: navigation - /about gets active class")
  Rw_AssertContains(result54, ">About</a>", "Accept 54: navigation - About label present")
  Rw_AssertContains(result54, ">Contact</a>", "Accept 54: navigation - Contact label present")
  ; Home and Contact should NOT have active class
  Rw_AssertNotContains(result54, "href=" + Chr(34) + "/" + Chr(34) + " class=" + Chr(34) + "active" + Chr(34), "Accept 54: navigation - home does not get active class")

  JinjaVariant::FreeVariant(@linksList54)

  ; --- 55_error_page.html: variables with default() filter, if/endif for show_details ---
  Protected tpl55.s = "<h1>{{ error_code|default(" + Chr(34) + "500" + Chr(34) + ") }} - " +
                       "{{ error_title|default(" + Chr(34) + "Internal Server Error" + Chr(34) + ") }}</h1>" + Chr(10) +
                       "<p>{{ message|default(" + Chr(34) + "An unexpected error occurred." + Chr(34) + ") }}</p>" + Chr(10) +
                       "{% if show_details %}" + Chr(10) +
                       "<pre>{{ details }}</pre>" + Chr(10) +
                       "{% endif %}"

  ; With all variables set
  Protected NewMap vars55a.JinjaVariant::JinjaVariant()
  JinjaVariant::IntVariant(@tmpV, 404)
  vars55a("error_code") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Not Found")
  vars55a("error_title") = tmpV
  JinjaVariant::StrVariant(@tmpV, "The page you requested could not be found.")
  vars55a("message") = tmpV
  JinjaVariant::BoolVariant(@tmpV, #True)
  vars55a("show_details") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Path: /missing-page")
  vars55a("details") = tmpV

  Protected result55a.s = Rw_RenderStr(tpl55, vars55a())
  Rw_AssertContains(result55a, "404 - Not Found", "Accept 55a: error_page - error code and title rendered")
  Rw_AssertContains(result55a, "The page you requested", "Accept 55a: error_page - custom message rendered")
  Rw_AssertContains(result55a, "<pre>Path: /missing-page</pre>", "Accept 55a: error_page - details shown when show_details=true")

  ; With only defaults (no variables provided)
  Protected NewMap vars55b.JinjaVariant::JinjaVariant()
  ; All variables absent - default() filter should supply fallback values
  ; show_details absent => falsy => details block hidden

  Protected result55b.s = Rw_RenderStr(tpl55, vars55b())
  Rw_AssertContains(result55b, "500 - Internal Server Error", "Accept 55b: error_page - default error code and title")
  Rw_AssertContains(result55b, "An unexpected error occurred.", "Accept 55b: error_page - default message")
  Rw_AssertNotContains(result55b, "<pre>", "Accept 55b: error_page - details hidden when show_details missing")

  ; With show_details = false (details block should be hidden)
  Protected NewMap vars55c.JinjaVariant::JinjaVariant()
  JinjaVariant::IntVariant(@tmpV, 403)
  vars55c("error_code") = tmpV
  JinjaVariant::StrVariant(@tmpV, "Forbidden")
  vars55c("error_title") = tmpV
  JinjaVariant::BoolVariant(@tmpV, #False)
  vars55c("show_details") = tmpV

  Protected result55c.s = Rw_RenderStr(tpl55, vars55c())
  Rw_AssertContains(result55c, "403 - Forbidden", "Accept 55c: error_page - 403 error rendered")
  Rw_AssertNotContains(result55c, "<pre>", "Accept 55c: error_page - details hidden when show_details=false")

  PrintN("")
EndProcedure
