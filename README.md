# WendaoCodeParser.jl

Native Julia and Modelica parser services for Wendao, exposed over Arrow
Flight.

This package owns:

1. Julia parsing through `JuliaSyntax.jl`
2. Modelica parsing through `OMParser.jl`
3. AST-query-level search under `src/search/`
4. normalization into a stable native Arrow Wendao parser contract
5. Arrow Flight request and response helpers built on `WendaoArrow`

Package boundary:

1. `WendaoCodeParser.jl` is parser-side only: it owns native parsing,
   normalization, and parser-route service behavior
2. it does not own Rust-side or host-side Flight client linkage
3. client linkage belongs in the Rust search, graph, and runtime integration
   layers that consume these parser routes

The initial slice keeps the Rust client cutover out of scope and proves the
provider contract first.

`WendaoSearch.jl` can also mount these parser routes into its existing live gRPC
service with `--code-parser-route-names`, so the same Arrow Flight process can
serve both graph-search routes and AST-query routes during local loopback tests.

Package docs now also live under `docs/`:

1. [Documentation Index](docs/index.md)
2. [Contracts Track](docs/contracts/README.md)
3. [Parser AST Alignment](docs/contracts/parser_ast_alignment.md)

Current backend status:

1. Julia summary and AST-query routes are implemented with `JuliaSyntax.jl`
2. Modelica summary and AST-query routes are implemented with `OMParser.jl`
3. When the upstream `Pkg.build("OMParser")` path is broken on macOS Julia 1.12,
   this package falls back to the official upstream source-build flow
   `lib/parser -> autoconf -> ./configure -> make`
4. The current workspace lock pins `OMParser.jl` to
   `https://github.com/tao3k/OMParser.jl` at
   `853c28d294339a611eaf60b08841ffb55b127db1` until the bootstrap fixes are
   consumed upstream

Native bridge note:

1. `OMParser.jl` still uses a native parse bridge that resolves `Absyn`,
   `ImmutableList`, and `MetaModelica` from `Main` during parser
   initialization
2. `WendaoCodeParser.jl` therefore aliases those already-loaded modules into
   `Main` before the first Modelica parse, especially for mounted live-child
   startup under `WendaoSearch.jl`
3. This runtime requirement is separate from the upstream `OMParser.jl`
   build/bootstrap lane: the upstream PR still matters for `Pkg.build(...)`,
   release assets, and CI coverage, but it does not by itself close the live
   child startup contract

Current route surface:

1. `julia_file_summary`
2. `julia_root_summary`
3. `modelica_file_summary`
4. `julia_ast_query`
5. `modelica_ast_query`

Parser layout note:

1. `src/parsers/julia/core.jl` owns Julia state collection, summary extraction,
   and AST node materialization
2. `src/parsers/julia/state.jl` owns Julia collection-state containers
3. `src/parsers/julia/summary.jl` owns Julia parser responses and summary-item
   shaping
4. `src/parsers/julia/emit.jl` owns Julia summary and AST row emission helpers
5. `src/parsers/julia/syntax.jl` owns `JuliaSyntax.SyntaxNode` inspection,
   naming, and line-span helpers
6. `src/parsers/julia/collect.jl` owns SyntaxNode traversal and Julia summary
   or AST state collection
7. `src/parsers/modelica/backend.jl` now only owns the `OMParser.jl` native
   bridge and shared-library/runtime bootstrap
8. `src/parsers/modelica/collect.jl` owns Modelica state collection, cache
   lifecycle, expression normalization, and AST node materialization
9. `src/parsers/modelica/summary.jl` owns Modelica summary shaping over the
   collected state
10. `src/search/` consumes those language-owned state collectors instead of
   reimplementing parser traversal logic

Contract note:

1. schema version `v3` uses native Arrow rows for both summary and AST routes
2. summary responses emit typed `summary_item_rows` plus stable scalar columns
   such as `module_name`, `class_name`, and `restriction`, plus nullable
   detail columns such as `item_visibility`, `item_owner_name`,
   `item_line_start`, `item_line_end`, `item_is_partial`,
   `item_is_encapsulated`, `item_component_kind`, `item_default_value`, and
   `item_unit`
3. AST requests carry typed query columns such as `node_kind`,
   `name_contains`, `text_contains`, and `limit`; there is no `query_json`
   fallback
4. AST responses return one `ast_match_rows` Arrow row per match, with fields
   such as `match_index`, `match_node_kind`, `match_name`, `match_text`,
   `match_signature`, and line spans
5. Julia summary and AST collection now run directly on
   `JuliaSyntax.SyntaxNode`, including `@reexport using`, module docstrings,
   symbol docstrings, first-line function signatures, and source-accurate line
   spans
6. Julia docstring rows now separate the doc-literal span
   (`line_start` / `line_end`) from the bound declaration span
   (`target_line_start` / `target_line_end`), so search consumers do not need
   to guess which semantic the parser encoded
7. Modelica documentation comments are normalized before they become summary
   items or AST nodes, so clients receive semantic content instead of raw
   `//`, `/*`, or `*` lexer markers
8. the Modelica backend now keeps a bounded same-source parse-state cache in
   the service process, keyed by exact `source_id` plus `source_text`, so
   repeated AST queries do not call `OMParser` again for unchanged input
9. Modelica native summary rows now expose parser-side visibility, owner,
   type-name, qualifier, equation, component-kind, default-value, and unit
   detail without widening into any Rust-side adapter work
10. package tests are now split under `test/support/` and `test/cases/`, so
   `test/runtests.jl` stays as a small runner instead of a monolithic file

The package also ships a focused helper for prebuilding the Modelica backend:

```bash
direnv exec . julia --project=. \
  scripts/build_omparser.jl
```
