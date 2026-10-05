; extends

; Newer Go grammars wrap statements in statement_list; older ones do not.
; Use a wildcard for that wrapper so both grammar versions accept this query.
([
  (block
    (comment) @_sql
    . (_
        . (short_var_declaration
            right: (expression_list
              (raw_string_literal (raw_string_literal_content) @injection.content)))))
  ((comment) @_sql
   . (short_var_declaration
       right: (expression_list
         (raw_string_literal (raw_string_literal_content) @injection.content))))
 ]
 (#eq? @_sql "// language=SQL")
 (#set! injection.language "sql"))
