
## PureJinja -- Jinja Template Engine for PureBasic

**Version:** 1.4.0 (Feature-complete, all tiers, 599/599 tests)
**Language:** PureBasic 6.x (procedural, cross-platform)
**Architecture:** Lexer -> Parser -> Renderer pipeline with tagged-union Variant type system

## PureBasic Project Index (pindex)

This project uses pindex for AI-friendly code indexing. Before modifying code:

1. Check freshness: `pindex check`
2. If stale, re-index: `pindex index`
3. Read indexes: `.pb_index/codetree.json` for symbols, `.pb_index/dependencies.json` for includes
4. After editing files: `pindex index --file <changed-file>` for incremental update

## Documentation

- [README.md](README.md) -- Project overview and quick start
- [QUICKSTART.md](QUICKSTART.md) -- 5-minute hands-on tutorial
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) -- Full API reference and usage guide
- [ARCHITECTURE.md](ARCHITECTURE.md) -- Technical deep-dive into design patterns
- [FEASIBILITY_STUDY.md](FEASIBILITY_STUDY.md) -- Original feasibility analysis (completed)
- [CHANGELOG.md](CHANGELOG.md) -- Version history
- [JINJA_TO_HTML_WALKTHROUGH.md](JINJA_TO_HTML_WALKTHROUGH.md) -- Code walkthrough for the CLI demo app

## Testing

```bash
# macOS / Linux
pbcompiler -cl Tests/TestRunner.pb -o Tests/TestRunner && ./Tests/TestRunner

# Windows
pbcompiler /cl Tests\TestRunner.pb /exe Tests\TestRunner.exe && Tests\TestRunner.exe
```

33 source files, 16 test modules, 599 tests covering all features.

## Cross-Platform Guidelines

This project targets Windows, macOS, and Linux. Follow these rules when adding code:

1. **Path separators:** Use `Jinja::#SEP` (defined in `Core/Constants.pbi`) when building file paths at runtime. Never hardcode `"/"` or `"\"` as separators.
2. **Avoid PureBasic reserved names in constants:** Do not use names that end with PureBasic built-in constants (e.g., `#Null`, `#True`, `#False`). PB 6.30+ on Windows treats `#VT_Null` as a collision with `#Null`. Use `#VT_None` instead.
3. **File I/O:** Always use `#PB_UTF8 | #PB_File_IgnoreEOL` when reading template files to handle line endings correctly on all platforms.
4. **No OS-specific APIs:** Keep all code pure PureBasic. If platform-specific behavior is needed, use `CompilerIf #PB_Compiler_OS` blocks.
5. **Testing:** Run the full test suite on Windows before merging. The `#VT_Null` collision was only caught at compile time on Windows.
