; extends

((expression_statement
   (assignment
     left: (identifier) @_name
     right: (string (string_content) @injection.content)))
 (#eq? @_name "query")
 (#set! injection.language "sql"))
