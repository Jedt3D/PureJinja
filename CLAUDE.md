
## PureJinja -- Jinja2 Template Engine for PureBasic

**Version:** 1.3.0 (Feature-complete, all tiers, 599/599 tests)
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

## Testing

```bash
pbcompiler -cl Tests/TestRunner.pb -o Tests/TestRunner && ./Tests/TestRunner
```

33 source files, 16 test modules, 599 tests covering all features.
