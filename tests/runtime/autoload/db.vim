function! db#resolve(db) abort
  return a:db
endfunction

function! db#connect(db) abort
  call add(g:test_connections, [a:db, bufnr('%'), &filetype])
  return a:db
endfunction
