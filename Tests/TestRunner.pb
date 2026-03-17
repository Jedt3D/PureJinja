; ============================================================================
; PureJinja - TestRunner.pb
; Console test application - compile with: pbcompiler -cl Tests/TestRunner.pb
; ============================================================================
EnableExplicit

XIncludeFile "../PureJinja.pbi"

; --- Test Framework ---
Global gTestsPassed.i = 0
Global gTestsFailed.i = 0
Global gTestsTotal.i  = 0

Procedure AssertEqual(actual.s, expected.s, testName.s)
  gTestsTotal + 1
  If actual = expected
    gTestsPassed + 1
    PrintN("[PASS] " + testName)
  Else
    gTestsFailed + 1
    PrintN("[FAIL] " + testName)
    PrintN("  Expected: " + Chr(34) + expected + Chr(34))
    PrintN("  Actual:   " + Chr(34) + actual + Chr(34))
  EndIf
EndProcedure

Procedure AssertTrue(value.i, testName.s)
  gTestsTotal + 1
  If value
    gTestsPassed + 1
    PrintN("[PASS] " + testName)
  Else
    gTestsFailed + 1
    PrintN("[FAIL] " + testName)
    PrintN("  Expected: True")
    PrintN("  Actual:   False")
  EndIf
EndProcedure

Procedure AssertFalse(value.i, testName.s)
  gTestsTotal + 1
  If Not value
    gTestsPassed + 1
    PrintN("[PASS] " + testName)
  Else
    gTestsFailed + 1
    PrintN("[FAIL] " + testName)
    PrintN("  Expected: False")
    PrintN("  Actual:   True")
  EndIf
EndProcedure

; --- Include Test Suites ---
XIncludeFile "TestVariant.pbi"
XIncludeFile "TestLexer.pbi"
XIncludeFile "TestParser.pbi"
XIncludeFile "TestRenderer.pbi"
XIncludeFile "TestFilters.pbi"
XIncludeFile "TestIntegration.pbi"
XIncludeFile "TestAcceptance.pbi"
XIncludeFile "TestInheritance.pbi"
XIncludeFile "TestRealWorld.pbi"
XIncludeFile "TestWhitespace.pbi"
XIncludeFile "TestRaw.pbi"

; --- Main ---
OpenConsole()
PrintN("=== PureJinja Test Suite v" + Jinja::#JINJA_VERSION$ + " ===")
PrintN("")

RunVariantTests()
RunLexerTests()
RunParserTests()
RunRendererTests()
RunFilterTests()
RunIntegrationTests()
RunAcceptanceTests()
RunInheritanceTests()
RunRealWorldTests()
RunWhitespaceTests()
RunRawTests()

PrintN("=== Results ===")
PrintN("Passed: " + Str(gTestsPassed) + "/" + Str(gTestsTotal))
If gTestsFailed > 0
  PrintN("FAILED: " + Str(gTestsFailed) + " test(s)")
Else
  PrintN("ALL TESTS PASSED")
EndIf

CloseConsole()
