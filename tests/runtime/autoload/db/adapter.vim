function! db#adapter#call(db, method, args, default) abort
  let g:test_table_fetches += 1
  return ['products', 'payments', 'Order Details']
endfunction

function! db#adapter#dispatch(db, method) abort
  return ['mock-db']
endfunction
