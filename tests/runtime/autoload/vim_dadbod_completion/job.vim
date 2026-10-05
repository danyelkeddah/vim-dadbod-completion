" Only database I/O is mocked; production connection resolution, cache, SQL
" context, alias parser, quoting and completion providers run unchanged.
function! vim_dadbod_completion#job#run(cmd, Callback, ...) abort
  let query = join(a:cmd, ' ')
  if query =~# 'COUNT('
    call a:Callback(['total', '6'])
  elseif query =~# 'routine_name'
    call a:Callback([])
  elseif query =~# 'TABLE_SCHEMA'
    call a:Callback(['public|products', 'public|payments'])
  else
    call a:Callback(['products|id', 'products|name', 'products|product_only', 'products|Order', 'payments|id', 'payments|payment_only'])
  endif
endfunction
