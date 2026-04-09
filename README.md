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
5. The current workspace lock pins `WendaoArrow.jl` to
   `https://github.com/tao3k/WendaoArrow.jl.git` at
   `334615136a8b68f18eedc614e0cc5ad33494ecc8` instead of a local sibling path,
   so package resolution and GitHub Actions use the same Arrow transport
   revision

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

1. `src/parsers/julia/mod.jl` re-exports the Julia parser owner surface
2. Julia parsing is split across focused files instead of a monolithic parser
   source
3. `src/parsers/julia/state.jl` owns Julia collection-state containers
4. `src/parsers/julia/summary.jl` owns Julia parser responses and summary-item
   shaping
5. `src/parsers/julia/emit.jl` owns Julia summary and AST row emission helpers
6. `src/parsers/julia/syntax.jl` owns `JuliaSyntax.SyntaxNode` inspection,
   naming, and line-span helpers
7. `src/parsers/julia/functions.jl` owns parser-native Julia function-header
   extraction such as arity, varargs, `where` clauses, and return annotations
8. `src/parsers/julia/collect.jl` owns SyntaxNode traversal and Julia summary
   or AST state collection
9. `src/parsers/modelica/backend.jl` now only owns the `OMParser.jl` native
   bridge and shared-library/runtime bootstrap
10. `src/parsers/modelica/collect.jl` owns Modelica state collection, cache
   lifecycle, expression normalization, and AST node materialization
11. `src/parsers/modelica/summary.jl` owns Modelica summary shaping over the
   collected state
12. `src/search/` consumes those language-owned state collectors instead of
   reimplementing parser traversal logic
13. `src/search/query/` now splits AST query parsing, node filtering, and
   match projection into focused files, so parser-side search semantics do not
   grow back into one flat query source

Contract note:

1. schema version remains `v3` in the current workspace; additive native Arrow
   column expansion does not advance the published version until the next
   GitHub release cut
2. summary responses emit typed `summary_item_rows` plus stable scalar columns
   such as `module_name`, `module_kind`, `class_name`, and `restriction`,
   plus nullable detail columns such as `item_visibility`,
   `item_owner_name`, `item_owner_kind`, `item_owner_path`,
   `item_module_name`, `item_module_path`, `item_class_path`,
   `item_target_path`, `item_line_start`, `item_line_end`,
   `item_binding_kind`, `item_type_kind`, `item_is_partial`,
   `item_is_encapsulated`, `item_component_kind`,
   `item_array_dimensions`, `item_default_value`, `item_start_value`,
   `item_modifier_names`, `item_unit`,
   `item_function_positional_arity`, `item_function_keyword_arity`,
   `item_function_has_varargs`, `item_function_where_params`, and
   `item_function_return_type`
3. AST requests carry typed query columns such as `node_kind`,
   `name_equals`, `name_contains`, `text_contains`, `signature_contains`,
   `attribute_key`, `attribute_equals`, `attribute_contains`, and `limit`;
   there is no `query_json` fallback
4. AST responses return one `ast_match_rows` Arrow row per match, with fields
   such as `match_index`, `match_node_kind`, `match_name`, `match_text`,
   `match_signature`, `match_target_kind`, `match_module`, `match_path`,
   `match_module_kind`, `match_owner_name`, `match_owner_kind`,
   `match_owner_path`, `match_module_name`, `match_module_path`,
   `match_class_path`, `match_target_path`, `match_binding_kind`,
   `match_type_kind`, `match_function_positional_arity`,
   `match_function_keyword_arity`, `match_function_has_varargs`,
   `match_function_where_params`, `match_function_return_type`,
   `match_array_dimensions`, `match_start_value`, `match_modifier_names`,
   line spans, `match_attribute_key`, and `match_attribute_value`
5. Julia summary and AST collection now run directly on
   `JuliaSyntax.SyntaxNode`, including `@reexport using`, module docstrings,
   symbol docstrings, first-line function signatures, top-level `const` or
   `global` bindings, macro definitions, explicit `module_kind`
   normalization for `module` versus `baremodule`, explicit `type_kind`
   normalization for `struct`, `mutable_struct`, `abstract_type`, and
   `primitive_type`, and source-accurate line spans
6. Julia function rows now also expose parser-owned function-header detail
   from `JuliaSyntax.jl`, including positional arity, keyword arity,
   varargs, `where` parameters, return annotations, positional parameter
   names, keyword parameter names, defaulted parameter names, typed parameter
   names, and explicit positional or keyword vararg names
7. same-scope Julia function methods are now preserved as distinct summary and
   AST rows instead of being collapsed by short name; consumers can
   disambiguate methods with parser-owned `signature` plus source span, while
   `path` exposes the stable base symbol path
8. Julia parameter rows now also expose one parser-owned summary item and AST
   node per parameter, including `parameter_kind`, `parameter_type_name`,
   `parameter_default_value`, `parameter_is_typed`,
   `parameter_is_defaulted`, `parameter_is_vararg`, plus method-level
   `target_path` so overloaded methods can be audited without flattening
9. Julia docstring rows now separate the doc-literal span
   (`line_start` / `line_end`) from the bound declaration span
   (`target_line_start` / `target_line_end`), so search consumers do not need
   to guess which semantic the parser encoded
10. Modelica documentation comments are normalized before they become summary
   items or AST nodes, so clients receive semantic content instead of raw
   `//`, `/*`, or `*` lexer markers
11. the Modelica backend now keeps a bounded same-source parse-state cache in
   the service process, keyed by exact `source_id` plus `source_text`, so
   repeated AST queries do not call `OMParser` again for unchanged input
12. Modelica native summary rows now expose parser-side visibility, owner,
   type-name, qualifier, equation, component-kind, array-dimension,
   default-value, modifier-name, start-value, and unit detail without
   widening into any Rust-side adapter work
13. AST search now resolves `attribute_key` against parser-owned top-level node
   fields first and then against parser-owned `metadata`, so search can reuse
   native provider detail instead of inventing parallel search-only schema
14. parser-native AST search can now query Julia attributes such as
   `reexported`, `target_kind`, `target_line_start`, `target_line_end`,
   `module_name`, `module_path`, `owner_name`, `owner_kind`, `owner_path`,
   `path`, `function_positional_arity`, `function_keyword_arity`,
   `function_has_varargs`, `function_where_params`, or
   `function_return_type`, `function_positional_params`,
   `function_keyword_params`, `function_defaulted_params`,
   `function_typed_params`, `function_positional_vararg_name`, or
   `function_keyword_vararg_name`, `parameter_kind`,
   `parameter_type_name`, `parameter_default_value`,
   `parameter_is_typed`, `parameter_is_defaulted`, or
   `parameter_is_vararg`, and Modelica attributes such as
   `owner_name`, `owner_path`, `class_path`, `visibility`, `type_name`,
   `variability`, `direction`, `component_kind`, `array_dimensions`,
   `default_value`, `start_value`, `modifier_names`, `unit`,
   `restriction`, `is_partial`, `is_final`, or `is_encapsulated`
15. scoped parser ownership now participates in dedup: repeated short names in
   different Julia modules or different Modelica class scopes are preserved as
   distinct AST nodes instead of being collapsed globally
16. package tests are now split under `test/support/` and `test/cases/`, so
   `test/runtests.jl` stays as a small runner instead of a monolithic file
17. parser-specific Flight round-trip coverage is now isolated in
   `test/cases/flight_native_columns.jl`, and mounted shared-service parser
   regressions are isolated in `WendaoSearch.jl/test/integration/live_code_parser.jl`

The package also ships a focused helper for prebuilding the Modelica backend:

```bash
direnv exec . julia --project=. \
  scripts/build_omparser.jl
```

GitHub Actions note:

1. package-local CI now runs `Pkg.build()` plus `Pkg.test()` on
   `ubuntu-latest` and `macos-latest` for Julia `1.12` and `pre`
2. a separate nightly workflow runs weekly on `ubuntu-latest`
3. both workflows bootstrap `General` plus `OpenModelicaRegistry` before build
   and test, so remote runners do not depend on preinstalled registries
