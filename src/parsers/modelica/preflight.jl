struct UnsupportedModelicaSyntaxError <: Exception
    source_id::String
    line::Int
    column::Int
    detail::String
    statement::String
end

function Base.showerror(io::IO, error::UnsupportedModelicaSyntaxError)
    print(
        io,
        "unsupported Modelica syntax in ",
        error.source_id,
        " at line ",
        error.line,
        ", column ",
        error.column,
        ": ",
        error.detail,
    )
    statement = _compact_modelica_statement(error.statement)
    isempty(statement) || print(io, " [statement: ", statement, "]")
    return nothing
end

function validate_modelica_source_preflight!(
    source_text::AbstractString,
    source_id::AbstractString,
)
    chars = collect(String(source_text))
    import_buffer = IOBuffer()
    capturing_import = false
    import_start_line = 1
    import_start_column = 1
    grouped_import_line = nothing
    grouped_import_column = nothing
    in_string = false
    escaped = false
    in_line_comment = false
    in_block_comment = false
    line = 1
    column = 1
    index = 1

    while index <= length(chars)
        char = chars[index]
        next_char = index < length(chars) ? chars[index+1] : '\0'

        if in_line_comment
            line, column = _advance_modelica_position(char, line, column)
            char == '\n' && (in_line_comment = false)
            index += 1
            continue
        elseif in_block_comment
            if char == '*' && next_char == '/'
                line, column = _advance_modelica_position(char, line, column)
                line, column = _advance_modelica_position(next_char, line, column)
                in_block_comment = false
                index += 2
                continue
            end
            line, column = _advance_modelica_position(char, line, column)
            index += 1
            continue
        elseif in_string
            capturing_import && _append_modelica_statement_char!(import_buffer, char)
            if escaped
                escaped = false
            elseif char == '\\'
                escaped = true
            elseif char == '"'
                in_string = false
            end
            line, column = _advance_modelica_position(char, line, column)
            index += 1
            continue
        end

        if char == '/' && next_char == '/'
            in_line_comment = true
            line, column = _advance_modelica_position(char, line, column)
            line, column = _advance_modelica_position(next_char, line, column)
            index += 2
            continue
        elseif char == '/' && next_char == '*'
            in_block_comment = true
            line, column = _advance_modelica_position(char, line, column)
            line, column = _advance_modelica_position(next_char, line, column)
            index += 2
            continue
        end

        if !capturing_import && _matches_modelica_import_keyword(chars, index)
            import_buffer = IOBuffer()
            import_start_line = line
            import_start_column = column
            grouped_import_line = nothing
            grouped_import_column = nothing
            capturing_import = true
            for offset = 0:5
                import_char = chars[index+offset]
                _append_modelica_statement_char!(import_buffer, import_char)
                line, column = _advance_modelica_position(import_char, line, column)
            end
            index += 6
            continue
        end

        if char == '"'
            capturing_import && _append_modelica_statement_char!(import_buffer, char)
            in_string = true
        elseif capturing_import && char == ';'
            _append_modelica_statement_char!(import_buffer, char)
            _validate_modelica_statement!(
                String(take!(import_buffer)),
                String(source_id),
                import_start_line,
                import_start_column,
                grouped_import_line,
                grouped_import_column,
            )
            capturing_import = false
            grouped_import_line = nothing
            grouped_import_column = nothing
        elseif capturing_import
            _append_modelica_statement_char!(import_buffer, char)
            if char == '{' && isnothing(grouped_import_line)
                grouped_import_line = line
                grouped_import_column = column
            end
        end

        line, column = _advance_modelica_position(char, line, column)
        index += 1
    end

    return nothing
end

function _validate_modelica_statement!(
    statement::AbstractString,
    source_id::String,
    statement_start_line::Int,
    statement_start_column::Int,
    grouped_import_line::Union{Nothing,Int},
    grouped_import_column::Union{Nothing,Int},
)
    statement_text = strip(String(statement))
    isempty(statement_text) && return nothing
    _is_modelica_import_statement(statement_text) || return nothing
    occursin('{', statement_text) && occursin('}', statement_text) || return nothing
    error_line = something(grouped_import_line, statement_start_line)
    error_column = something(grouped_import_column, statement_start_column)
    throw(
        UnsupportedModelicaSyntaxError(
            source_id,
            error_line,
            error_column,
            "grouped imports are not yet supported by the current OMParser bridge",
            statement_text,
        ),
    )
end

function _is_modelica_import_statement(statement::AbstractString)
    return !isnothing(match(r"^import\b"i, String(statement)))
end

function _matches_modelica_import_keyword(chars::Vector{Char}, index::Int)
    index + 5 <= length(chars) || return false
    previous_char = index == 1 ? nothing : chars[index-1]
    next_char = index + 6 <= length(chars) ? chars[index+6] : nothing
    !_is_modelica_identifier_char(previous_char) || return false
    !_is_modelica_identifier_char(next_char) || return false
    return lowercase(chars[index]) == 'i' &&
           lowercase(chars[index+1]) == 'm' &&
           lowercase(chars[index+2]) == 'p' &&
           lowercase(chars[index+3]) == 'o' &&
           lowercase(chars[index+4]) == 'r' &&
           lowercase(chars[index+5]) == 't'
end

function _is_modelica_identifier_char(char::Union{Nothing,Char})
    isnothing(char) && return false
    return isletter(char) || isdigit(char) || char == '_'
end

function _compact_modelica_statement(statement::AbstractString)
    return join(split(strip(String(statement))), " ")
end

function _append_modelica_statement_char!(buffer::IOBuffer, char::Char)
    write(buffer, char)
    return nothing
end

function _advance_modelica_position(char::Char, line::Int, column::Int)
    char == '\n' && return (line + 1, 1)
    return (line, column + 1)
end
