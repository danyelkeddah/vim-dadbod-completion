set nocompatible
let &runtimepath = getcwd().'/tests/runtime,'.getcwd().','.$VIMRUNTIME
let g:vim_dadbod_completion_disable_notifications = 1
let g:test_connections = []
let g:test_table_fetches = 0
runtime plugin/vim_dadbod_completion.vim
let b:db = 'postgresql://vim/test'
set filetype=sql
call setline(1, ['SELECT p. FROM products AS p', 'SELECT * FROM pro'])
call cursor(1, 10)
call assert_equal(9, vim_dadbod_completion#omni(1, ''))
let s:items = vim_dadbod_completion#omni(0, '')
call assert_true(index(map(copy(s:items), 'v:val.abbr'), 'product_only') >= 0)
call assert_equal(-1, index(map(copy(s:items), 'v:val.abbr'), 'payment_only'))
call cursor(2, 18)
call assert_true(index(map(vim_dadbod_completion#omni(0, 'pro'), 'v:val.abbr'), 'products') >= 0)
call assert_equal(1, g:test_table_fetches)
if !empty(v:errors)
  call writefile(v:errors, '/dev/stderr')
  cquit 1
endif
qa!
