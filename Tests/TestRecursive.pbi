; ============================================================================
; PureJinja - TestRecursive.pbi
; Tests for recursive for loops ({% for item in tree recursive %})
; ============================================================================
EnableExplicit

; --- Helper: render with a given variable map ---
Procedure.s Rec_Render(templateStr.s, Map variables.JinjaVariant::JinjaVariant())
  JinjaError::ClearError()
  Protected NewList rctokens.JinjaToken::Token()
  JinjaLexer::Tokenize(templateStr, rctokens())
  If JinjaError::HasError()
    ProcedureReturn "[LexError] " + JinjaError::FormatError()
  EndIf

  Protected *rcast.JinjaAST::ASTNode = JinjaParser::Parse(rctokens())
  If JinjaError::HasError()
    ProcedureReturn "[ParseError] " + JinjaError::FormatError()
  EndIf

  Protected *rcenv.JinjaEnv::JinjaEnvironment = JinjaEnv::CreateEnvironment()
  *rcenv\Autoescape = #False
  Protected rcresult.s = JinjaRenderer::Render(*rcenv, *rcast, variables())
  JinjaEnv::FreeEnvironment(*rcenv)
  JinjaAST::FreeAST(*rcast)
  ProcedureReturn rcresult
EndProcedure

; Helper: Free all JinjaVariant entries in the vars map
Procedure Rec_FreeVars(Map vars.JinjaVariant::JinjaVariant())
  ForEach vars()
    JinjaVariant::FreeVariant(@vars())
  Next
  ClearMap(vars())
EndProcedure

Procedure RunRecursiveTests()
  PrintN("--- Recursive For Loop Tests ---")

  Protected NewMap vars.JinjaVariant::JinjaVariant()
  Protected tmpV.JinjaVariant::JinjaVariant
  Protected result.s

  ; ==========================================================================
  ; Test 1: Simple flat list with 'recursive' keyword (no loop() calls)
  ; Verifies the keyword is parsed without error and loop renders normally
  ; ==========================================================================
  Rec_FreeVars(vars())

  ; Build items = [{name:"x"}, {name:"y"}] directly in the vars map
  JinjaVariant::NewListVariant(@vars("items"))

  ; Build each item as a local variant and add it to the list
  Protected itemA.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@itemA)
  Protected nameV.JinjaVariant::JinjaVariant
  JinjaVariant::StrVariant(@nameV, "x")
  JinjaVariant::VMapSet(@itemA, "name", @nameV)
  JinjaVariant::VListAdd(@vars("items"), @itemA)
  JinjaVariant::FreeVariant(@itemA)

  Protected itemB.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@itemB)
  JinjaVariant::StrVariant(@nameV, "y")
  JinjaVariant::VMapSet(@itemB, "name", @nameV)
  JinjaVariant::VListAdd(@vars("items"), @itemB)
  JinjaVariant::FreeVariant(@itemB)

  result = Rec_Render("{% for item in items recursive %}{{ item.name }}{% endfor %}", vars())
  AssertEqual(result, "xy", "Recursive: flat list renders normally with recursive keyword")

  ; ==========================================================================
  ; Test 2: Simple tree - one level deep
  ; tree = [{name: "a", children: [{name: "b"}, {name: "c"}]}, {name: "d"}]
  ; Expected: a[bc]d
  ; ==========================================================================
  Rec_FreeVars(vars())

  ; Build the tree directly into vars("tree")
  JinjaVariant::NewListVariant(@vars("tree"))

  ; Node "a" with children [b, c]
  Protected nodeA.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeA)
  JinjaVariant::StrVariant(@nameV, "a")
  JinjaVariant::VMapSet(@nodeA, "name", @nameV)

  ; Build children list for "a"
  Protected childrenA.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@childrenA)

  Protected nodeB.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeB)
  JinjaVariant::StrVariant(@nameV, "b")
  JinjaVariant::VMapSet(@nodeB, "name", @nameV)
  JinjaVariant::VListAdd(@childrenA, @nodeB)
  JinjaVariant::FreeVariant(@nodeB)

  Protected nodeC.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeC)
  JinjaVariant::StrVariant(@nameV, "c")
  JinjaVariant::VMapSet(@nodeC, "name", @nameV)
  JinjaVariant::VListAdd(@childrenA, @nodeC)
  JinjaVariant::FreeVariant(@nodeC)

  JinjaVariant::VMapSet(@nodeA, "children", @childrenA)
  JinjaVariant::FreeVariant(@childrenA)

  JinjaVariant::VListAdd(@vars("tree"), @nodeA)
  JinjaVariant::FreeVariant(@nodeA)

  ; Node "d" (leaf)
  Protected nodeD.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeD)
  JinjaVariant::StrVariant(@nameV, "d")
  JinjaVariant::VMapSet(@nodeD, "name", @nameV)
  JinjaVariant::VListAdd(@vars("tree"), @nodeD)
  JinjaVariant::FreeVariant(@nodeD)

  result = Rec_Render("{% for item in tree recursive %}{{ item.name }}{% if item.children %}[{{ loop(item.children) }}]{% endif %}{% endfor %}", vars())
  AssertEqual(result, "a[bc]d", "Recursive: simple tree a[bc]d")

  ; ==========================================================================
  ; Test 3: All leaf nodes (no children key) - should just output names
  ; ==========================================================================
  Rec_FreeVars(vars())
  JinjaVariant::NewListVariant(@vars("tree"))

  Protected nodeP.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeP)
  JinjaVariant::StrVariant(@nameV, "p")
  JinjaVariant::VMapSet(@nodeP, "name", @nameV)
  JinjaVariant::VListAdd(@vars("tree"), @nodeP)
  JinjaVariant::FreeVariant(@nodeP)

  Protected nodeQ.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeQ)
  JinjaVariant::StrVariant(@nameV, "q")
  JinjaVariant::VMapSet(@nodeQ, "name", @nameV)
  JinjaVariant::VListAdd(@vars("tree"), @nodeQ)
  JinjaVariant::FreeVariant(@nodeQ)

  result = Rec_Render("{% for item in tree recursive %}{{ item.name }}{% if item.children %}[{{ loop(item.children) }}]{% endif %}{% endfor %}", vars())
  AssertEqual(result, "pq", "Recursive: all leaves (no children)")

  ; ==========================================================================
  ; Test 4: Deeper nesting (3 levels)
  ; tree = [{name: "r", children: [{name: "s", children: [{name: "t"}]}]}]
  ; Expected: r[s[t]]
  ; ==========================================================================
  Rec_FreeVars(vars())
  JinjaVariant::NewListVariant(@vars("tree"))

  ; Level 3: node "t" (leaf)
  Protected nodeT.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeT)
  JinjaVariant::StrVariant(@nameV, "t")
  JinjaVariant::VMapSet(@nodeT, "name", @nameV)

  ; Level 3 children list: [t]
  Protected childrenT.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@childrenT)
  JinjaVariant::VListAdd(@childrenT, @nodeT)
  JinjaVariant::FreeVariant(@nodeT)

  ; Level 2: node "s" with children [t]
  Protected nodeS.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeS)
  JinjaVariant::StrVariant(@nameV, "s")
  JinjaVariant::VMapSet(@nodeS, "name", @nameV)
  JinjaVariant::VMapSet(@nodeS, "children", @childrenT)
  JinjaVariant::FreeVariant(@childrenT)

  ; Level 2 children list: [s]
  Protected childrenS.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@childrenS)
  JinjaVariant::VListAdd(@childrenS, @nodeS)
  JinjaVariant::FreeVariant(@nodeS)

  ; Level 1: node "r" with children [s]
  Protected nodeR.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeR)
  JinjaVariant::StrVariant(@nameV, "r")
  JinjaVariant::VMapSet(@nodeR, "name", @nameV)
  JinjaVariant::VMapSet(@nodeR, "children", @childrenS)
  JinjaVariant::FreeVariant(@childrenS)

  JinjaVariant::VListAdd(@vars("tree"), @nodeR)
  JinjaVariant::FreeVariant(@nodeR)

  result = Rec_Render("{% for item in tree recursive %}{{ item.name }}{% if item.children %}[{{ loop(item.children) }}]{% endif %}{% endfor %}", vars())
  AssertEqual(result, "r[s[t]]", "Recursive: 3-level nesting r[s[t]]")

  ; ==========================================================================
  ; Test 5: loop() with empty children list produces no output
  ; ==========================================================================
  Rec_FreeVars(vars())
  JinjaVariant::NewListVariant(@vars("tree"))

  ; node "a" with empty children list
  Protected nodeAA.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@nodeAA)
  JinjaVariant::StrVariant(@nameV, "a")
  JinjaVariant::VMapSet(@nodeAA, "name", @nameV)
  Protected emptyChildren.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@emptyChildren)  ; empty list
  JinjaVariant::VMapSet(@nodeAA, "children", @emptyChildren)
  JinjaVariant::FreeVariant(@emptyChildren)

  JinjaVariant::VListAdd(@vars("tree"), @nodeAA)
  JinjaVariant::FreeVariant(@nodeAA)

  result = Rec_Render("{% for item in tree recursive %}{{ item.name }}{% if item.children %}[{{ loop(item.children) }}]{% endif %}{% endfor %}", vars())
  AssertEqual(result, "a", "Recursive: empty children list renders just the parent name")

  ; ==========================================================================
  ; Test 6: Multiple children at root, multiple children in subtrees
  ; tree = [{name:"1", children:[{name:"1a"},{name:"1b"}]},
  ;         {name:"2", children:[{name:"2a"}]},
  ;         {name:"3"}]
  ; Expected: 1[1a1b]2[2a]3
  ; ==========================================================================
  Rec_FreeVars(vars())
  JinjaVariant::NewListVariant(@vars("tree"))

  ; Build node "1" with children "1a", "1b"
  Protected node1a.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@node1a)
  JinjaVariant::StrVariant(@nameV, "1a")
  JinjaVariant::VMapSet(@node1a, "name", @nameV)

  Protected node1b.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@node1b)
  JinjaVariant::StrVariant(@nameV, "1b")
  JinjaVariant::VMapSet(@node1b, "name", @nameV)

  Protected children1.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@children1)
  JinjaVariant::VListAdd(@children1, @node1a)
  JinjaVariant::VListAdd(@children1, @node1b)
  JinjaVariant::FreeVariant(@node1a)
  JinjaVariant::FreeVariant(@node1b)

  Protected node1.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@node1)
  JinjaVariant::StrVariant(@nameV, "1")
  JinjaVariant::VMapSet(@node1, "name", @nameV)
  JinjaVariant::VMapSet(@node1, "children", @children1)
  JinjaVariant::FreeVariant(@children1)

  JinjaVariant::VListAdd(@vars("tree"), @node1)
  JinjaVariant::FreeVariant(@node1)

  ; Build node "2" with child "2a"
  Protected node2a.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@node2a)
  JinjaVariant::StrVariant(@nameV, "2a")
  JinjaVariant::VMapSet(@node2a, "name", @nameV)

  Protected children2.JinjaVariant::JinjaVariant
  JinjaVariant::NewListVariant(@children2)
  JinjaVariant::VListAdd(@children2, @node2a)
  JinjaVariant::FreeVariant(@node2a)

  Protected node2.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@node2)
  JinjaVariant::StrVariant(@nameV, "2")
  JinjaVariant::VMapSet(@node2, "name", @nameV)
  JinjaVariant::VMapSet(@node2, "children", @children2)
  JinjaVariant::FreeVariant(@children2)

  JinjaVariant::VListAdd(@vars("tree"), @node2)
  JinjaVariant::FreeVariant(@node2)

  ; Build node "3" (leaf)
  Protected node3.JinjaVariant::JinjaVariant
  JinjaVariant::NewMapVariant(@node3)
  JinjaVariant::StrVariant(@nameV, "3")
  JinjaVariant::VMapSet(@node3, "name", @nameV)
  JinjaVariant::VListAdd(@vars("tree"), @node3)
  JinjaVariant::FreeVariant(@node3)

  result = Rec_Render("{% for item in tree recursive %}{{ item.name }}{% if item.children %}[{{ loop(item.children) }}]{% endif %}{% endfor %}", vars())
  AssertEqual(result, "1[1a1b]2[2a]3", "Recursive: multiple children at multiple levels")

  ; Cleanup
  Rec_FreeVars(vars())

EndProcedure
