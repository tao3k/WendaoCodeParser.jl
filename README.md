# WendaoCodeParser.jl

Native Julia and Modelica parser services for Wendao, exposed over Arrow
Flight.

This package owns:

1. Julia parsing through `JuliaSyntax.jl`
2. Modelica parsing through `OMParser.jl`
3. AST-query-level search under `src/search/`
4. normalization into a stable Wendao parser-summary contract
5. Arrow Flight request and response helpers built on `WendaoArrow`

The initial slice keeps the Rust cutover out of scope and proves the provider
contract first.

`WendaoSearch.jl` can also mount these parser routes into its existing live gRPC
service with `--code-parser-route-names`, so the same Arrow Flight process can
serve both graph-search routes and AST-query routes during local loopback tests.

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

AST route contract note:

1. schema version `v2` keeps summary routes on their existing summary-payload
   shape but moves `julia_ast_query` and `modelica_ast_query` to native Arrow
   columns
2. AST requests now carry typed query columns such as `node_kind`,
   `name_contains`, `text_contains`, and `limit`
3. AST responses now return one Arrow row per match, with fields such as
   `match_index`, `match_node_kind`, `match_name`, `match_text`,
   `match_signature`, and line spans, instead of one `payload_json` blob
4. the Modelica backend now keeps a bounded same-source parse-state cache in
   the service process, keyed by exact `source_id` plus `source_text`, so
   repeated AST queries do not call `OMParser` again for unchanged input

The package also ships a focused helper for prebuilding the Modelica backend:

```bash
direnv exec . julia --project=. \
  scripts/build_omparser.jl
```
