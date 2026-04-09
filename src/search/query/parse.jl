function _parse_ast_query(request::ParserRequest)
    return AstQuery(
        node_kind = request.node_kind,
        name_equals = request.name_equals,
        name_contains = request.name_contains,
        text_contains = request.text_contains,
        signature_contains = request.signature_contains,
        attribute_key = request.attribute_key,
        attribute_equals = request.attribute_equals,
        attribute_contains = request.attribute_contains,
        limit = request.limit,
    )
end
