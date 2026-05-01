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

Service runtime:

1. `scripts/run_service.jl` starts the parser-summary and AST-query Flight
   service directly from this package
2. `config/live/parser_summary.toml` is the package-local live-service
   descriptor for the default Julia and Modelica parser routes
3. `contracts/wendaocodeparser_parser_summary.toml` is the package-local
   route and transport contract consumed by Rust integration tests

Start the default service:

```bash
julia --project=. scripts/run_service.jl --config config/live/parser_summary.toml
```

Override listener fields without changing the package-owned route contract:

```bash
julia --project=. scripts/run_service.jl \
  --config config/live/parser_summary.toml \
  --host 127.0.0.1 \
  --port 41081
```

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
   `cebc0696407385e52496608fcc13e95a556da3b5` until the bootstrap fixes are
   consumed upstream
5. The current workspace lock pins `WendaoArrow.jl` to
   `https://github.com/tao3k/WendaoArrow.jl.git` at
   `3325a646785e022a3286d08f28b19dafb4e7c8dd`
6. The package also pins the inherited `Arrow.jl`, `ArrowTypes`, and
   `PureHTTP2.jl` transport sources directly in `Project.toml`, so clean
   package resolution and GitHub Actions do not rely on a workflow-local
   inherited-source bootstrap

Native bridge note:

1. `OMParser.jl` still uses a native parse bridge that resolves `Absyn`,
   `ImmutableList`, and `MetaModelica` from `Main` during parser
   initialization
2. `WendaoCodeParser.jl` therefore aliases those already-loaded modules into
   `Main` before the first Modelica parse
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
7. `src/parsers/julia/types.jl` owns parser-native Julia type-header
   extraction such as type parameters, supertypes, and primitive bit widths
8. `src/parsers/julia/dependencies.jl` owns Julia `import`, `using`,
   `include`, and shared dependency normalization
9. `src/parsers/julia/functions.jl` owns parser-native Julia function-header
   extraction such as arity, varargs, `where` clauses, and return annotations
10. `src/parsers/julia/collect.jl` owns SyntaxNode traversal and Julia summary
   or AST state collection
11. `src/parsers/modelica/backend.jl` now only owns the `OMParser.jl` native
   bridge and shared-library/runtime bootstrap
12. `src/parsers/modelica/nodes.jl` owns generic Modelica AST node
    materialization
13. `src/parsers/modelica/dependencies.jl` owns Modelica `import` / `extends`
    emission plus shared dependency summary shaping
14. `src/parsers/modelica/collect.jl` owns Modelica state collection, cache
    lifecycle, expression normalization, and non-dependency AST traversal
15. `src/parsers/modelica/summary.jl` owns Modelica summary shaping over the
   collected state
16. `src/search/` consumes those language-owned state collectors instead of
   reimplementing parser traversal logic
17. `src/search/query/` now splits AST query parsing, node filtering, and
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
   `item_root_module_name`, `item_module_name`, `item_module_path`,
   `item_class_path`, `item_target_name`, `item_target_path`,
   `item_top_level`, `item_line_start`, `item_line_end`,
   `item_dependency_kind`, `item_dependency_form`,
   `item_dependency_target`, `item_dependency_is_relative`,
   `item_dependency_relative_level`, `item_dependency_local_name`,
   `item_dependency_parent`, `item_dependency_member`,
   `item_dependency_alias`,
   `item_binding_kind`, `item_type_kind`, `item_type_parameters`,
   `item_type_supertype`, `item_primitive_bits`, `item_is_partial`,
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
   `match_signature`, `match_target_kind`, `match_target_name`,
   `match_module`, `match_path`, `match_module_kind`,
   `match_dependency_kind`, `match_dependency_form`,
   `match_dependency_target`, `match_dependency_is_relative`,
   `match_dependency_relative_level`, `match_dependency_local_name`,
   `match_dependency_parent`, `match_dependency_member`,
   `match_dependency_alias`,
   `match_owner_name`, `match_owner_kind`,
   `match_owner_path`, `match_root_module_name`, `match_module_name`,
   `match_module_path`, `match_class_path`, `match_target_path`,
   `match_top_level`, `match_binding_kind`,
   `match_type_kind`, `match_type_parameters`, `match_type_supertype`,
   `match_primitive_bits`, `match_function_positional_arity`,
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
6. Julia type rows now also expose parser-owned type-header detail such as
   `type_parameters`, `type_supertype`, and `primitive_bits`, so generic and
   primitive declaration structure stays queryable without re-parsing the
   signature string on the search side
7. Julia function rows now also expose parser-owned function-header detail
   from `JuliaSyntax.jl`, including positional arity, keyword arity,
   varargs, `where` parameters, return annotations, positional parameter
   names, keyword parameter names, defaulted parameter names, typed parameter
   names, and explicit positional or keyword vararg names
8. same-scope Julia function methods are now preserved as distinct summary and
   AST rows instead of being collapsed by short name; consumers can
   disambiguate methods with parser-owned `signature` plus source span, while
   `path` exposes the stable base symbol path
9. Julia parameter rows now also expose one parser-owned summary item and AST
   node per parameter, including `parameter_kind`, `parameter_type_name`,
   `parameter_default_value`, `parameter_is_typed`,
   `parameter_is_defaulted`, `parameter_is_vararg`, plus method-level
   `target_path` so overloaded methods can be audited without flattening
10. Julia docstring rows now separate the doc-literal span
   (`line_start` / `line_end`) from the bound declaration span
   (`target_line_start` / `target_line_end`), so search consumers do not need
   to guess which semantic the parser encoded
11. Julia dependency rows now preserve parser-owned dependency semantics
    through shared `dependency_kind`, `dependency_target`,
    `dependency_is_relative`, `dependency_relative_level`,
    `dependency_local_name`, `dependency_parent`, `dependency_member`, and
    `dependency_alias` fields, so `import`, `using`, and `include` can be
    queried through one normalized dependency contract without replacing the
    existing language-native groups
12. Julia dependency rows now also preserve parser-owned local binding names
    such as `rd`, `DataFrame`, `BT`, `Utils`, and `foo`, so search can query
    the name that becomes visible in the current scope instead of re-deriving
    it from alias, member, or target strings
13. Julia dependency rows now also preserve parser-owned syntax forms such as
    `path`, `member`, `alias`, `aliased_member`, and `include`, so search can
    distinguish direct imports, selective imports, aliased imports, and
    include edges without re-parsing the dependency target
14. Julia relative dependency rows now also preserve parser-owned leading-dot
    semantics such as `using ..Parent: foo`, `import .Utils`, and
    `import ..Core: bar as baz`, so search can query relative imports without
    inferring dot depth from raw dependency strings
15. Modelica documentation comments are normalized before they become summary
   items or AST nodes, so clients receive semantic content instead of raw
   `//`, `/*`, or `*` lexer markers
16. the Modelica backend now keeps a bounded same-source parse-state cache in
   the service process, keyed by exact `source_id` plus `source_text`, so
   repeated AST queries do not call `OMParser` again for unchanged input
17. Modelica native summary rows now expose parser-side visibility, owner,
   type-name, qualifier, equation, component-kind, array-dimension,
   default-value, modifier-name, start-value, and unit detail without
   widening into any Rust-side adapter work
18. Modelica `import` and `extends` rows now also expose the same shared
    `dependency_kind`, `dependency_target`, and named-import
    `dependency_alias` detail used by Julia dependency rows, so parser-side
    search can audit dependency semantics without re-deriving language-specific
    targets in `src/search/`
19. Modelica import rows now also expose parser-owned `dependency_local_name`
    such as `SI` and `Math`, so the local binding visible in Modelica scope is
    queryable over the native Arrow contract instead of being inferred from
    target-path leaf segments
20. Modelica dependency rows now also expose parser-owned syntax forms such as
    `named_import`, `qualified_import`, `unqualified_import`, and `extends`,
    so native search can distinguish imported binding shapes without
    reconstructing the Modelica source string on the host side
21. Modelica qualified and unqualified imports now remain distinct parser
    rows even when they target the same module path inside one class scope, so
    search does not collapse `import Modelica.Math;` and
    `import Modelica.Math.*;` into one dependency row
22. Modelica named imports now also expose parser-owned `dependency_alias`
    detail, while grouped imports now fail as deterministic parser-owned
    errors before the native bridge instead of aborting the service process
23. AST search now resolves `attribute_key` against parser-owned top-level node
   fields first and then against parser-owned `metadata`, so search can reuse
   native provider detail instead of inventing parallel search-only schema
24. parser-native AST search now treats identifier-list fields such as
   `function_keyword_params`, `function_defaulted_params`,
   `function_typed_params`, `function_positional_params`, and
   `modifier_names` as parser-owned list semantics during attribute matching,
   so `attribute_equals` can match one list member and
   `match_attribute_value` reports the exact matched member instead of the
   whole serialized field
25. parser-native AST search now also treats parser-owned boolean and integer
   fields as typed scalars during `attribute_equals`, so values such as
   `function_has_varargs = true`, `function_positional_arity = 4`,
   `dependency_relative_level = 2`, `is_partial = true`, or `line_start = 2`
   are matched by native scalar equality instead of weak stringification;
   `attribute_contains` remains textual or identifier-list specific
26. parser-native AST search can now query Julia attributes such as
   `reexported`, `target_kind`, `target_name`, `target_line_start`,
   `target_line_end`, `root_module_name`, `top_level`, `module_name`, `module_path`,
   `owner_name`, `owner_kind`, `owner_path`, `path`, `dependency_kind`,
   `dependency_form`, `dependency_target`, `dependency_is_relative`,
   `dependency_relative_level`,
   `dependency_local_name`, `dependency_parent`, `dependency_member`,
   `dependency_alias`, `type_parameters`, `type_supertype`,
   `primitive_bits`,
   `function_positional_arity`, `function_keyword_arity`,
   `function_has_varargs`, `function_where_params`, or
   `function_return_type`, `function_positional_params`,
   `function_keyword_params`, `function_defaulted_params`,
   `function_typed_params`, `function_positional_vararg_name`, or
   `function_keyword_vararg_name`, `parameter_kind`,
   `parameter_type_name`, `parameter_default_value`,
   `parameter_is_typed`, `parameter_is_defaulted`, or
   `parameter_is_vararg`, and Modelica attributes such as
   `owner_name`, `owner_path`, `class_path`, `top_level`,
   `dependency_kind`, `dependency_form`, `dependency_target`,
   `dependency_local_name`, `dependency_alias`, `visibility`, `type_name`,
   `variability`, `direction`, `component_kind`, `array_dimensions`,
   `default_value`, `start_value`, `modifier_names`, `unit`,
   `restriction`, `is_partial`, `is_final`, or `is_encapsulated`
27. scoped parser ownership now participates in dedup: repeated short names in
   different Julia modules or different Modelica class scopes are preserved as
   distinct AST nodes instead of being collapsed globally
28. package tests are now split under `test/support/` and `test/cases/`, so
   `test/runtests.jl` stays as a small runner instead of a monolithic file
29. parser-specific Flight round-trip coverage is isolated in
   `test/cases/flight_native_columns.jl`, while parser-service route parsing,
   listener config, and multiplexed live-service behavior are covered in
   `test/cases/flight_services.jl`
30. AST match rows now also promote parser-owned stable columns such as
   `match_target_name`, `match_root_module_name`, `match_top_level`,
   `match_reexported`, `match_visibility`, `match_type_name`,
   `match_variability`, `match_direction`, `match_component_kind`,
   `match_default_value`, `match_unit`, `match_is_partial`,
   `match_is_final`, and `match_is_encapsulated`, so mounted consumers do not
   have to recover those semantics only through `match_attribute_key` /
   `match_attribute_value`
31. Julia scope-owned rows now also propagate parser-owned `top_level`
    semantics through summary and AST rows, so root-module declarations and
    nested-module declarations stay distinguishable without reconstructing
    scope only from `owner_path` or `module_path`
32. Julia parameter rows now also expose parser-owned `owner_signature`
    detail through summary and AST rows, so overloaded-method parameter
    searches can disambiguate method ownership without relying only on
    synthesized `target_path`

GitHub Actions note:

1. package-local CI now runs `Pkg.build()` plus `Pkg.test()` on
   `ubuntu-latest` and `macos-latest` for Julia `1.12` and `pre`
2. a separate nightly workflow runs weekly on `ubuntu-latest`
3. both workflows bootstrap `General` plus `OpenModelicaRegistry` before
   running `Pkg.resolve()`, `Pkg.instantiate()`, `Pkg.build()`, and package
   tests, so remote runners resolve the same source-locked transport stack as
   local runs
