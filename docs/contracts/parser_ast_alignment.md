---
type: knowledge
title: "Parser AST Alignment"
category: "contracts"
tags:
  - wendao_code_parser
  - parser
  - ast
  - contract
metadata:
  title: "Parser AST Alignment"
---

# Parser AST Alignment

This document records the migration order and compatibility rules for replacing
Rust-owned Julia and Modelica parsing with
`WendaoCodeParser.jl`.

## 1. Status

Status: package-local draft

Schema version: `v3`

This draft exists to keep the Rust replacement order explicit while package
docs track native Julia and Modelica parser ownership behind Arrow Flight.
The workspace keeps the published schema label at `v3` until a release cut,
even when additive native Arrow columns land locally.

## 2. Migration Order

The governed rollout order is:

1. replace the Rust-owned Julia and Modelica parser entrypoints in
   `xiuxian-ast`
2. align the Rust compatibility surface around the current summary and AST
   semantics that those callers already consume
3. expand Rust-visible AST search only after the compatibility surface is
   stable

This order is deliberate. Search should not be the first cutover surface. The
first cutover surface is the existing Rust-owned parser compatibility layer.

## 3. Current Rust Compatibility Surface

There is no single shared parser trait in Rust today. The practical
compatibility surface is the combination of exported summary structs and the
call sites that instantiate the tree-sitter parsers.

Current Rust-owned Julia parser surface:

1. `xiuxian_ast::TreeSitterJuliaParser`
2. `xiuxian_ast::JuliaFileSummary`
3. `xiuxian_ast::JuliaSourceSummary`
4. `packages/rust/crates/xiuxian-wendao-julia/src/plugin/sources.rs`

Current Rust-owned Modelica parser surface:

1. `xiuxian_ast::TreeSitterModelicaParser`
2. `xiuxian_ast::ModelicaFileSummary`
3. `packages/rust/crates/xiuxian-wendao-modelica/src/plugin/parsing.rs`

That means the first alignment target is not an abstract trait. It is the
concrete compatibility behavior embodied by those types and call sites.

## 4. Native Parser Ownership Boundary

`WendaoCodeParser.jl` owns:

1. Julia parsing through `JuliaSyntax.jl`
2. Modelica parsing through `OMParser.jl`
3. summary normalization into native Arrow rows
4. AST node materialization for `julia_ast_query` and `modelica_ast_query`
5. mounted Flight service behavior when those routes are hosted under
   `WendaoSearch.jl`

`WendaoCodeParser.jl` does not own:

1. Rust-side or host-side Flight clients
2. plugin-local client transport inside `xiuxian-wendao-julia` or
   `xiuxian-wendao-modelica`
3. search, graph, or runtime client linkage in `xiuxian-wendao`

Rust continues to own:

1. compatibility structs until consumer cutover is complete
2. repo-intelligence domain mapping in `xiuxian-wendao-julia` and
   `xiuxian-wendao-modelica`
3. the Flight client seam that consumes parser routes from the search, graph,
   or runtime layer
4. the decision about when the native AST search routes become Rust-consumable
   product surfaces

## 5. Alignment Rules

The compatibility alignment follows these rules:

1. native Julia and Modelica parsing semantics come from the language-native
   providers, not from Rust tree-sitter fallbacks
2. Flight is the only sanctioned parser execution boundary between Julia and
   Rust for this lane
3. Rust replacement happens summary-first; AST search expansion happens after
   summary compatibility is proven
4. parser-owned collectors define the normalized AST vocabulary, and search
   consumes that vocabulary instead of re-deriving tree shapes separately
5. documentation text is normalized before it becomes a summary item or AST
   node, so callers consume semantic content instead of lexer markers
6. AST search must reuse parser-owned fields and metadata through native Arrow
   request columns instead of introducing JSON payloads or search-only parser
   shadow schema
7. this package remains parser-side only throughout the cutover; it must not
   grow a parser-local Rust or host client surface
8. when Rust consumers cut over, the client linkage belongs in the consuming
   search, graph, or runtime layer, not in the language parser owners

## 6. Current Native Alignment Surface

Current Julia summary groups:

1. `export`
2. `import`
3. `symbol`
4. `parameter`
5. `docstring`
6. `include`

Current Julia AST node kinds:

1. `module`
2. `export`
3. `import`
4. `include`
5. `function`
6. `type`
7. `binding`
8. `macro`
9. `docstring`

Current native Julia detail coverage:

1. source-accurate `line_start` and `line_end` values derived from
   `JuliaSyntax.SyntaxNode` ranges
2. `@reexport using` import rows with explicit `reexported = true`
3. module and symbol docstrings that keep parser-side doc-literal spans plus
   explicit bound-declaration spans through `target_line_start` and
   `target_line_end`
4. first-line function signatures for both short-form and block-form function
   declarations
5. scoped module ownership metadata through `module_name`, `module_path`,
   `owner_name`, `owner_kind`, and `owner_path`
6. scoped dedup so nested modules with the same short declaration names remain
   distinct parser nodes
7. top-level binding coverage for `const` and `global` declarations through
   `binding_kind`
8. native macro definition coverage, including summary rows, AST rows, and
   docstring target linkage for parser-owned `macro` nodes
9. explicit Julia type classification through `type_kind`, including
   `mutable_struct`
10. explicit Julia module classification through `module_kind`, including
    `baremodule`
11. richer Julia type classification through `type_kind = abstract_type` and
    `type_kind = primitive_type`
12. parser-owned Julia type-header detail through `type_parameters`,
    `type_supertype`, and primitive `primitive_bits`
13. parser-owned Julia function-header detail through
    `function_positional_arity`, `function_keyword_arity`,
    `function_has_varargs`, `function_where_params`, and
    `function_return_type`
14. parser-owned Julia function-parameter detail through
    `function_positional_params`, `function_keyword_params`,
    `function_defaulted_params`, `function_typed_params`,
    `function_positional_vararg_name`, and
    `function_keyword_vararg_name`
15. same-scope Julia function methods are preserved as distinct parser rows
    and AST nodes instead of being collapsed by short name; consumers
    disambiguate methods through parser-owned `signature`, `line_start`,
    `line_end`, and base `path`
16. Julia function parameters are now also materialized as parser-owned
    summary items and AST nodes through `parameter_kind`,
    `parameter_type_name`, `parameter_default_value`,
    `parameter_is_typed`, `parameter_is_defaulted`,
    `parameter_is_vararg`, method-level `target_path`, and
    `owner_signature`
17. shared dependency detail is now normalized through `dependency_kind`,
    `dependency_form`, `dependency_target`, `dependency_is_relative`,
    `dependency_relative_level`, `dependency_local_name`,
    `dependency_parent`, `dependency_member`, and `dependency_alias`, so
    parser-owned dependency semantics stay queryable across `import`,
    `using`, and `include` without introducing a search-only schema
18. Julia dependency rows now retain native selective-import and alias
    semantics such as `import CSV: read as rd` and `using DataFrames:
    DataFrame`, instead of collapsing them into one flat dependency string
19. Julia dependency rows now also retain local binding names such as `rd`,
    `DataFrame`, `BT`, `Utils`, and `foo`, so consumers can query the symbol
    introduced into scope instead of inferring it from target strings
20. Julia dependency rows now also retain syntax-form detail such as `path`,
    `member`, `alias`, `aliased_member`, and `include`, so consumers can
    distinguish import shapes without re-parsing the source text
21. Julia dependency rows now also retain relative-import semantics such as
    `using ..Parent: foo`, `import .Utils`, and
    `import ..Core: bar as baz`, with explicit parser-owned
    `dependency_is_relative` and `dependency_relative_level` detail

Current Modelica summary groups:

1. `import`
2. `extend`
3. `symbol`
4. `equation`
5. `documentation`

Current native Modelica summary detail columns:

1. visibility and owner linkage through nullable `item_visibility` and
   `item_owner_name`
2. component typing detail through nullable `item_type_name`,
   `item_variability`, and `item_direction`
3. component parity detail through nullable `item_component_kind`,
   `item_array_dimensions`, `item_default_value`, `item_start_value`,
   `item_modifier_names`, and `item_unit`
4. source span detail through nullable `item_line_start` and `item_line_end`
5. class qualifier detail through nullable `item_is_partial`,
   `item_is_final`, and `item_is_encapsulated`
6. direct parser summary items now also retain scoped ownership metadata such
   as `owner_path` and nested class identity through `class_path`
7. parser-owned structural scope metadata is now promoted into stable native
   summary columns such as `item_owner_kind`, `item_owner_path`,
   `item_root_module_name`, `item_module_name`, `item_module_path`,
   `item_class_path`, `item_target_name`, `item_target_path`, and
   `item_top_level`
8. shared dependency detail is now normalized through `dependency_kind`,
   `dependency_form`, `dependency_target`, `dependency_local_name`, and
   `dependency_alias`, so Modelica `import` and `extends` rows align with the Julia dependency
   contract without erasing language-native groups
9. current Modelica import alignment now exposes local binding names such as
   `SI` and `Math`, so native search can query scope-visible Modelica imports
   without splitting dependency targets
10. current Modelica import alignment now also exposes syntax forms such as
    `named_import`, `qualified_import`, `unqualified_import`, and `extends`,
    so consumers can audit native Modelica import shapes directly over Arrow
    rows
11. current Modelica import alignment preserves both `qualified_import` and
    `unqualified_import` rows even when they target the same module path,
    so search can distinguish `import Modelica.Math;` from
    `import Modelica.Math.*;` without re-deriving import shape from source text
12. current Modelica import alignment covers named, qualified, and
   unqualified imports; grouped imports are rejected as deterministic
   parser-owned preflight errors before the native bridge, so the package
   contract returns structured failure instead of process abort

Current Modelica AST node kinds:

1. restriction-derived class nodes such as `model`, `function`, `record`,
   `package`, `connector`, and related restriction names
2. `component`
3. `import`
4. `extends`
5. `equation`
6. `documentation`

Current native AST query columns:

1. `node_kind`
2. `name_equals`
3. `name_contains`
4. `text_contains`
5. `signature_contains`
6. `attribute_key`
7. `attribute_equals`
8. `attribute_contains`
9. `limit`

Current native AST query resolution rules:

1. `attribute_key` resolves against a parser-owned top-level AST node field
   first and then against parser-owned `metadata`
2. response rows echo the resolved queried attribute through
   `match_attribute_key` and `match_attribute_value`
3. identifier-list fields such as `function_keyword_params`,
   `function_defaulted_params`, `function_typed_params`,
   `function_positional_params`, and `modifier_names` now use parser-owned
   list semantics during attribute filtering, so `attribute_equals` matches an
   individual member and `match_attribute_value` reports the matched member
   rather than the full serialized field
4. parser-owned boolean and integer fields now also use native scalar equality
   during `attribute_equals`, so fields such as `function_has_varargs`,
   `function_positional_arity`, `dependency_relative_level`, `is_partial`, or
   `line_start` are matched by typed value instead of stringification;
   `attribute_contains` remains textual or identifier-list specific
5. Julia search can therefore filter directly on provider-owned attributes such
   as `reexported`, `target_kind`, `target_name`, `target_line_start`,
   `target_line_end`, `root_module_name`, `top_level`, `module_name`, `module_path`,
   `owner_name`, `owner_kind`, `owner_path`, `binding_kind`, `type_kind`,
   `type_parameters`, `type_supertype`, `primitive_bits`, `module_kind`,
   `dependency_kind`, `dependency_form`, `dependency_target`,
   `dependency_is_relative`, `dependency_relative_level`,
   `dependency_local_name`, `dependency_parent`, `dependency_member`, `dependency_alias`,
   `function_positional_arity`, `function_keyword_arity`,
   `function_has_varargs`, `function_where_params`, and
   `function_return_type`
6. Modelica search can therefore filter directly on provider-owned attributes
   such as `owner_name`, `owner_path`, `class_path`, `top_level`,
   `dependency_kind`, `dependency_form`, `dependency_target`,
   `dependency_local_name`, `dependency_alias`, `visibility`, `type_name`,
   `variability`, `direction`, `component_kind`, `array_dimensions`,
   `default_value`, `start_value`, `modifier_names`, `unit`, `restriction`,
   `is_partial`, `is_final`, and `is_encapsulated`
7. AST match rows now also project parser-owned structural fields into stable
   columns such as `match_target_kind`, `match_target_name`,
   `match_module`, `match_path`, `match_owner_name`, `match_owner_kind`,
   `match_owner_path`, `match_root_module_name`, `match_module_name`,
   `match_module_path`, `match_class_path`, `match_target_path`, and
   `match_top_level`, so mounted consumers do not need to recover those
   semantics only through `match_attribute_key` / `match_attribute_value`
8. AST match rows now also project parser-owned qualifier and symbol-detail
   fields into stable columns such as `match_reexported`, `match_visibility`,
   `match_type_name`, `match_variability`, `match_direction`,
   `match_component_kind`, `match_default_value`, `match_unit`,
   `match_is_partial`, `match_is_final`, and `match_is_encapsulated`, so
   mounted consumers can audit those native parser semantics directly over
   Arrow rows

## 7. Alignment Tracker

Current checkpoint status:

1. Rust parser replacement order defined: done
2. language-owned parser modules in `WendaoCodeParser.jl`: done
3. Julia `SyntaxNode` collector and parser-folder modularization: done
4. native Arrow row contract for summary and AST routes: done
5. Julia docstring and Modelica documentation AST parity: done
6. Modelica native summary detail parity for visibility, equations, line spans,
   and class qualifiers: done
7. Modelica native component-detail parity for kind, default-value, and unit:
   done
8. native parser-attribute AST search seam over Arrow rows: done
9. scoped ownership alignment for nested Julia and Modelica declarations: done
10. native scope-column promotion for summary and AST rows: done
11. Julia declaration coverage for bindings, macros, and mutable structs: done
12. Julia module-kind and richer type-kind normalization: done
13. Modelica component modifier alignment for dimensions, start values, and
    modifier names: done
14. Julia function-header alignment for arity, varargs, `where`, and return
    annotations: done
15. dependency local-name alignment across Julia and Modelica imports: done
16. dependency syntax-form alignment across Julia and Modelica imports: done
17. Julia type-header alignment for type parameters, supertypes, and primitive
    bit widths: done
18. typed scalar search alignment for parser-owned bool/int fields: done
19. AST match stable-column promotion for parser-owned qualifier and symbol
    detail: done
20. stable scope and target column promotion for summary and AST rows: done
21. Julia top-level scope propagation across summary and AST rows: done
22. Julia parameter owner-signature promotion across summary and AST rows: done
23. Rust summary-surface replacement in `xiuxian-ast` callers: in progress
    (`xiuxian-wendao-julia` parser-summary client plus the
    `xiuxian-wendao` incremental host path no longer instantiate
    `TreeSitterJuliaParser` in the touched Julia slice, and the touched Rust
    surface now treats missing or disabled `parser_summary_transport` config as
    an explicit Flight-contract failure)
24. Rust-visible AST search promotion: pending

Current compatibility risk to track:

1. Julia compatibility is close to the old Rust surface because the current
   summary fields now map cleanly to module, import, symbol, docstring,
   include, reexport, parser-owned line-span semantics, scoped module
   ownership, top-level binding kinds, macro definitions, module-kind
   normalization, richer type-kind normalization, parser-owned
   function-header semantics, parser-owned dependency local names,
   parser-owned dependency syntax forms, and parser-owned Julia type-header
   detail
2. Modelica compatibility is now materially closer than before, but it is
   still thinner than the old Rust `ModelicaFileSummary` because the old Rust
   surface nests component detail inside class symbols, while the native Arrow
   contract currently exposes the same information, including component array
   dimensions and modifier detail, as flattened symbol rows keyed by
   `owner_name` and `owner_path`
3. mounted live child startup still depends on the `OMParser.jl` native bridge
   resolving `Absyn`, `ImmutableList`, and `MetaModelica` from `Main`

## 8. Next Governed Steps

The next bounded implementation steps under this docs contract are:

1. keep `WendaoCodeParser.jl` parser-only while replacing
   `TreeSitterJuliaParser` and `TreeSitterModelicaParser` call sites from a
   Rust Flight-backed adapter
2. land that adapter in the consuming search, graph, or runtime layer rather
   than in this package
3. keep the touched Julia consumer surface on a Flight-only contract without
   reintroducing a Rust-local parser fallback or optional parser-summary
   transport semantics when parser-summary materialization fails
4. align the adapter output with `JuliaFileSummary`, `JuliaSourceSummary`, and
   the currently used subset of `ModelicaFileSummary`
5. audit whether Rust consumers need nested component reconstruction or can
   consume the native flattened Arrow rows keyed by `owner_name`
6. keep parser-package tests split across bounded `test/cases/` files so the
   parser runner does not grow back into a monolithic integration surface
7. keep mounted parser regressions isolated in dedicated shared-service test
   modules instead of expanding general live-service files
8. only then decide which native AST search capabilities should become
   Rust-visible traits or route contracts
