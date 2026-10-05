-- Run in a fresh process with only go.so installed: no SQL parser is loaded.
local root = vim.fn.getcwd()
vim.opt.runtimepath = { root, root .. '/tests/fixtures', vim.env.VIMRUNTIME, assert(vim.env.DADBOD_TEST_PARSERS) }
local ok, err = pcall(function()
  vim.bo.filetype = 'go'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    'package main', 'func f() {', '// language=SQL', 'q := `SELECT pro`', '}',
  })
  vim.api.nvim_win_set_cursor(0, { 4, 16 })
  local loaded, value = pcall(vim.treesitter.language.add, 'sql')
  assert(not loaded or value == nil, 'this test requires sql.so to be absent')
  local parser = vim.treesitter.get_parser(0)
  assert(parser:parse(true)[1], 'real Go parser should work')
  assert(require('vim_dadbod_completion.context').resolve() == nil)
  assert(not require('vim_dadbod_completion.blink').new():enabled())
  assert(not require('vim_dadbod_completion').nvim_cmp_source:is_available())
end)
if not ok then
  io.stderr:write(tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('PASS: missing SQL parser (real Go parser)')
  vim.cmd('qa!')
end
