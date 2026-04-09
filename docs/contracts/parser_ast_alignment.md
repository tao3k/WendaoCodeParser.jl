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
6. this package remains parser-side only throughout the cutover; it must not
   grow a parser-local Rust or host client surface
7. when Rust consumers cut over, the client linkage belongs in the consuming
   search, graph, or runtime layer, not in the language parser owners

## 6. Current Native Alignment Surface

Current Julia summary groups:

1. `export`
2. `import`
3. `symbol`
4. `docstring`
5. `include`

Current Julia AST node kinds:

1. `module`
2. `export`
3. `import`
4. `include`
5. `function`
6. `type`
7. `docstring`

Current native Julia detail coverage:

1. source-accurate `line_start` and `line_end` values derived from
   `JuliaSyntax.SyntaxNode` ranges
2. `@reexport using` import rows with explicit `reexported = true`
3. module and symbol docstrings that keep parser-side doc-literal spans plus
   explicit bound-declaration spans through `target_line_start` and
   `target_line_end`
4. first-line function signatures for both short-form and block-form function
   declarations

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
   `item_default_value`, and `item_unit`
4. source span detail through nullable `item_line_start` and `item_line_end`
5. class qualifier detail through nullable `item_is_partial`,
   `item_is_final`, and `item_is_encapsulated`

Current Modelica AST node kinds:

1. restriction-derived class nodes such as `model`, `function`, `record`,
   `package`, `connector`, and related restriction names
2. `component`
3. `import`
4. `extends`
5. `equation`
6. `documentation`

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
8. Rust summary-surface replacement in `xiuxian-ast` callers: pending
9. Rust-visible AST search promotion: pending

Current compatibility risk to track:

1. Julia compatibility is close to the old Rust surface because the current
   summary fields now map cleanly to module, import, symbol, docstring,
   include, reexport, and parser-owned line-span semantics
2. Modelica compatibility is now materially closer than before, but it is
   still thinner than the old Rust `ModelicaFileSummary` because the old Rust
   surface nests component detail inside class symbols, while the native Arrow
   contract currently exposes the same information as flattened symbol rows
   keyed by `owner_name`
3. mounted live child startup still depends on the `OMParser.jl` native bridge
   resolving `Absyn`, `ImmutableList`, and `MetaModelica` from `Main`

## 8. Next Governed Steps

The next bounded implementation steps under this docs contract are:

1. keep `WendaoCodeParser.jl` parser-only while replacing
   `TreeSitterJuliaParser` and `TreeSitterModelicaParser` call sites from a
   Rust Flight-backed adapter
2. land that adapter in the consuming search, graph, or runtime layer rather
   than in this package
3. align the adapter output with `JuliaFileSummary`, `JuliaSourceSummary`, and
   the currently used subset of `ModelicaFileSummary`
4. audit whether Rust consumers need nested component reconstruction or can
   consume the native flattened Arrow rows keyed by `owner_name`
5. keep parser-package tests split across bounded `test/cases/` files so the
   parser runner does not grow back into a monolithic integration surface
6. only then decide which native AST search capabilities should become
   Rust-visible traits or route contracts
