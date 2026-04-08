mutable struct JuliaCollectionState
    module_name::Union{Nothing,String}
    exports::Vector{String}
    export_set::Set{String}
    imports::Vector{Dict{String,Any}}
    import_set::Set{String}
    symbols::Vector{Dict{String,Any}}
    symbol_set::Set{Tuple{String,String}}
    docstrings::Vector{Dict{String,Any}}
    includes::Vector{String}
    include_set::Set{String}
    nodes::Vector{Dict{String,Any}}
end

function JuliaCollectionState()
    return JuliaCollectionState(
        nothing,
        String[],
        Set{String}(),
        Dict{String,Any}[],
        Set{String}(),
        Dict{String,Any}[],
        Set{Tuple{String,String}}(),
        Dict{String,Any}[],
        String[],
        Set{String}(),
        Dict{String,Any}[],
    )
end

function parse_julia_file_summary(request::ParserRequest)
    try
        state = _collect_julia_state(request.source_text)
        payload = Dict(
            "module_name" => state.module_name,
            "exports" => state.exports,
            "imports" => state.imports,
            "symbols" => state.symbols,
            "docstrings" => state.docstrings,
            "includes" => state.includes,
        )
        return ParserResponse(
            request.request_id,
            request.source_id,
            "julia_file_summary",
            "JuliaSyntax.jl";
            success = true,
            primary_name = state.module_name,
            payload_json = JSON3.write(payload),
        )
    catch error
        return _julia_failure_response(request, "julia_file_summary", error)
    end
end

function parse_julia_root_summary(request::ParserRequest)
    try
        state = _collect_julia_state(request.source_text)
        isnothing(state.module_name) &&
            error("Julia root summary requires one root module declaration")
        payload = Dict(
            "module_name" => state.module_name,
            "exports" => state.exports,
            "imports" => state.imports,
            "symbols" => state.symbols,
            "docstrings" => state.docstrings,
            "includes" => state.includes,
        )
        return ParserResponse(
            request.request_id,
            request.source_id,
            "julia_root_summary",
            "JuliaSyntax.jl";
            success = true,
            primary_name = state.module_name,
            payload_json = JSON3.write(payload),
        )
    catch error
        return _julia_failure_response(request, "julia_root_summary", error)
    end
end

function _julia_failure_response(
    request::ParserRequest,
    summary_kind::AbstractString,
    error,
)
    return ParserResponse(
        request.request_id,
        request.source_id,
        summary_kind,
        "JuliaSyntax.jl";
        success = false,
        error_message = sprint(showerror, error),
    )
end

function _collect_julia_state(source_text::AbstractString)
    parsed = JuliaSyntax.parseall(Expr, String(source_text))
    state = JuliaCollectionState()
    _collect_julia_item!(parsed, state, 1)
    return state
end

function _collect_julia_item!(item, state::JuliaCollectionState, current_line::Int)
    if item isa LineNumberNode
        return item.line
    elseif item isa Expr
        if item.head == :toplevel || item.head == :block
            local line = current_line
            for child in item.args
                line = _collect_julia_item!(child, state, line)
            end
            return line
        elseif item.head == :module
            module_name = string(item.args[2])
            isnothing(state.module_name) && (state.module_name = module_name)
            _push_ast_node!(
                state,
                "module",
                module_name;
                text = module_name,
                line_start = current_line,
                metadata = Dict("module_name" => module_name),
            )
            return _collect_julia_item!(item.args[3], state, current_line)
        elseif item.head == :export
            for child in item.args
                export_name = _julia_name_text(child)
                _push_export!(state, export_name, current_line)
            end
            return current_line
        elseif item.head == :using || item.head == :import
            for child in item.args
                import_name = _julia_import_module_text(child)
                isnothing(import_name) && continue
                _push_import!(state, something(import_name), current_line)
            end
            return current_line
        elseif _is_julia_include_call(item)
            include_literal = item.args[2]
            include_literal isa AbstractString || return current_line
            _push_include!(state, String(include_literal), current_line)
            return current_line
        elseif _is_short_julia_function(item)
            symbol_name = _julia_function_name(item.args[1])
            isnothing(symbol_name) || _push_symbol!(
                state,
                something(symbol_name),
                "function",
                sprint(show, item),
                current_line,
            )
            return current_line
        elseif item.head == :function
            symbol_name = _julia_function_name(item.args[1])
            isnothing(symbol_name) || _push_symbol!(
                state,
                something(symbol_name),
                "function",
                sprint(show, item),
                current_line,
            )
            return current_line
        elseif item.head == :struct
            symbol_name = string(item.args[2])
            _push_symbol!(state, symbol_name, "type", sprint(show, item), current_line)
            return current_line
        elseif item.head == :abstract
            symbol_name = string(item.args[1])
            _push_symbol!(state, symbol_name, "type", sprint(show, item), current_line)
            return current_line
        elseif item.head == :primitive
            symbol_name = string(item.args[1])
            _push_symbol!(state, symbol_name, "type", sprint(show, item), current_line)
            return current_line
        elseif item.head == :macrocall &&
               _is_julia_doc_macro(item.args[1]) &&
               length(item.args) >= 4
            content = item.args[3]
            target = item.args[4]
            target_info = _julia_doc_target(target)
            if !isnothing(target_info)
                _push_docstring!(
                    state,
                    target_info.name,
                    target_info.target_kind,
                    string(content),
                    current_line,
                )
            end
            _collect_julia_item!(target, state, current_line)
            return current_line
        end
    end
    return current_line
end

function _push_export!(state::JuliaCollectionState, export_name::String, line_start::Int)
    export_name in state.export_set && return nothing
    push!(state.export_set, export_name)
    push!(state.exports, export_name)
    _push_ast_node!(
        state,
        "export",
        export_name;
        text = export_name,
        line_start = line_start,
        metadata = Dict("name" => export_name),
    )
    return nothing
end

function _push_import!(state::JuliaCollectionState, import_name::String, line_start::Int)
    import_name in state.import_set && return nothing
    push!(state.import_set, import_name)
    entry = Dict{String,Any}("module" => import_name, "reexported" => false)
    push!(state.imports, entry)
    _push_ast_node!(
        state,
        "import",
        import_name;
        text = import_name,
        line_start = line_start,
        metadata = Dict("module" => import_name, "reexported" => false),
    )
    return nothing
end

function _push_symbol!(
    state::JuliaCollectionState,
    symbol_name::String,
    symbol_kind::String,
    signature::String,
    line_start::Int,
)
    symbol_key = (symbol_name, symbol_kind)
    symbol_key in state.symbol_set && return nothing
    push!(state.symbol_set, symbol_key)
    entry = Dict{String,Any}(
        "name" => symbol_name,
        "kind" => symbol_kind,
        "signature" => signature,
    )
    push!(state.symbols, entry)
    _push_ast_node!(
        state,
        symbol_kind,
        symbol_name;
        text = signature,
        line_start = line_start,
        signature = signature,
        metadata = Dict("name" => symbol_name, "kind" => symbol_kind),
    )
    return nothing
end

function _push_docstring!(
    state::JuliaCollectionState,
    target_name::String,
    target_kind::String,
    content::String,
    line_start::Int,
)
    entry = Dict{String,Any}(
        "target_name" => target_name,
        "target_kind" => target_kind,
        "content" => content,
    )
    push!(state.docstrings, entry)
    _push_ast_node!(
        state,
        "docstring",
        target_name;
        text = content,
        line_start = line_start,
        metadata = Dict("target_name" => target_name, "target_kind" => target_kind),
    )
    return nothing
end

function _push_include!(
    state::JuliaCollectionState,
    include_literal::String,
    line_start::Int,
)
    include_literal in state.include_set && return nothing
    push!(state.include_set, include_literal)
    push!(state.includes, include_literal)
    _push_ast_node!(
        state,
        "include",
        include_literal;
        text = include_literal,
        line_start = line_start,
        metadata = Dict("path" => include_literal),
    )
    return nothing
end

function _push_ast_node!(
    state::JuliaCollectionState,
    node_kind::String,
    name::String;
    text::Union{Nothing,String} = nothing,
    line_start::Union{Nothing,Int} = nothing,
    line_end::Union{Nothing,Int} = nothing,
    signature::Union{Nothing,String} = nothing,
    metadata = nothing,
)
    node = Dict{String,Any}(
        "node_kind" => node_kind,
        "name" => name,
        "text" => text,
        "line_start" => line_start,
        "line_end" => line_end,
        "signature" => signature,
        "metadata" =>
            isnothing(metadata) ? Dict{String,Any}() : Dict{String,Any}(metadata),
    )
    push!(state.nodes, node)
    return nothing
end

_is_julia_include_call(item::Expr) =
    item.head == :call &&
    !isempty(item.args) &&
    item.args[1] == :include &&
    length(item.args) >= 2

_is_short_julia_function(item::Expr) =
    item.head == :(=) &&
    !isempty(item.args) &&
    item.args[1] isa Expr &&
    item.args[1].head == :call

function _is_julia_doc_macro(value)
    if value isa Symbol
        return value == Symbol("@doc")
    elseif value isa GlobalRef
        return value.name == Symbol("@doc")
    elseif value isa Expr
        return sprint(show, value) == "Core.var\"@doc\""
    end
    return false
end

function _julia_doc_target(target)
    if target isa Expr && target.head == :module
        return (name = string(target.args[2]), target_kind = "module")
    end
    symbol_name = _julia_symbol_name(target)
    isnothing(symbol_name) && return nothing
    return (name = something(symbol_name), target_kind = "symbol")
end

function _julia_symbol_name(expr)
    if expr isa Expr && expr.head == :module
        return string(expr.args[2])
    elseif expr isa Expr && expr.head == :function
        return _julia_function_name(expr.args[1])
    elseif _is_short_julia_function(expr)
        return _julia_function_name(expr.args[1])
    elseif expr isa Expr && expr.head == :struct
        return string(expr.args[2])
    elseif expr isa Expr && expr.head == :abstract
        return string(expr.args[1])
    elseif expr isa Expr && expr.head == :primitive
        return string(expr.args[1])
    elseif expr isa Symbol
        return string(expr)
    end
    return nothing
end

function _julia_function_name(head_expr)
    if head_expr isa Symbol
        return string(head_expr)
    elseif head_expr isa Expr
        if head_expr.head == :call
            return _julia_function_name(head_expr.args[1])
        elseif head_expr.head == :where || head_expr.head == :(::)
            return _julia_function_name(head_expr.args[1])
        end
    end
    return nothing
end

function _julia_name_text(value)
    if value isa Symbol
        return string(value)
    elseif value isa Expr
        return sprint(show, value)
    end
    return string(value)
end

function _julia_import_module_text(value)
    if value isa Symbol
        return string(value)
    elseif value isa Expr
        if value.head == :.
            return _julia_dotted_name(value)
        elseif value.head == Symbol(":") && !isempty(value.args)
            return _julia_import_module_text(value.args[1])
        end
    end
    return nothing
end

function _julia_dotted_name(value::Expr)
    parts = String[]
    _collect_dotted_name_parts!(parts, value)
    isempty(parts) && return nothing
    return join(parts, ".")
end

function _collect_dotted_name_parts!(parts::Vector{String}, value)
    if value isa Expr && value.head == :.
        for child in value.args
            _collect_dotted_name_parts!(parts, child)
        end
    elseif value isa QuoteNode
        push!(parts, string(value.value))
    elseif value isa Symbol
        push!(parts, string(value))
    elseif value isa Expr
        push!(parts, sprint(show, value))
    end
    return nothing
end
