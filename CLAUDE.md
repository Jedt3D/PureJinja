
## PureBasic Project Index (pindex)

This project uses pindex for AI-friendly code indexing. Before modifying code:

1. Check freshness: `pindex check`
2. If stale, re-index: `pindex index`
3. Read indexes: `.pb_index/codetree.json` for symbols, `.pb_index/dependencies.json` for includes
4. After editing files: `pindex index --file <changed-file>` for incremental update
