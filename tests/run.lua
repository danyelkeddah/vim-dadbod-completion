local root = vim.fn.getcwd()
vim.opt.runtimepath = { root .. '/tests/runtime', root .. '/tests/fixtures', root, vim.env.VIMRUNTIME }
if vim.env.DADBOD_TEST_PARSERS then vim.opt.runtimepath:append(vim.env.DADBOD_TEST_PARSERS) end
vim.g.vim_dadbod_completion_disable_notifications = 1
vim.g.test_connections = {}
vim.g.test_table_fetches = 0
vim.opt.virtualedit = 'onemore'
local context = require('vim_dadbod_completion.context')
local blink = require('vim_dadbod_completion.blink').new()
local cmp = require('vim_dadbod_completion').nvim_cmp_source
local tests = 0
local function eq(actual, expected, message)
  assert(vim.deep_equal(actual, expected), (message or '') .. '\nexpected: ' .. vim.inspect(expected) .. '\nactual: ' .. vim.inspect(actual))
end
local function test(name, fn)
  fn()
  tests = tests + 1
  print('ok ' .. tests .. ' - ' .. name)
end
local function buffer(ft, lines)
  vim.cmd('enew!')
  vim.bo.filetype = ft
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.b.db = 'postgresql://host-buffer/test'
  return vim.api.nvim_get_current_buf()
end
local function at(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end
local function after(row, text)
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  local _, col = line:find(text, 1, true)
  assert(col, text .. ' not found: ' .. line)
  at(row, col)
end
local function complete(source)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local result
  if source == 'blink' then
    blink:get_completions({ bufnr = vim.api.nvim_get_current_buf(), cursor = cursor, line = line }, function(r) result = r.items end)
  else
    cmp:complete({ offset = 1, context = {
      bufnr = vim.api.nvim_get_current_buf(), cursor = { row = cursor[1], col = cursor[2] + 1 },
      cursor_before_line = line:sub(1, cursor[2]), cursor_line = line,
    } }, function(r) result = r.items end)
  end
  assert(result, 'provider must call back')
  return result
end
local function item(items, label)
  for _, value in ipairs(items) do if value.label == label then return value end end
end
local function columns(source, yes, no)
  local items = complete(source)
  assert(item(items, yes), 'missing ' .. yes .. ': ' .. vim.inspect(items))
  if no then assert(not item(items, no), 'leaked ' .. no) end
  return items
end
local function go()
  return buffer('go', vim.fn.readfile(root .. '/tests/fixtures/embedded.go'))
end
local function annotated(sql)
  return buffer('go', { 'package main', 'func f() {', '// language=SQL', 'q := `' .. sql .. '`', '}' })
end

local function run()
  test('standalone SQL never needs Tree-sitter (both providers and public omni)', function()
    local original = vim.treesitter.get_parser
    vim.treesitter.get_parser = function() error('must not call Tree-sitter') end
    for _, ft in ipairs({ 'sql', 'mysql', 'plsql' }) do
      buffer(ft, { 'SELECT p. FROM products p' })
      after(1, 'p.')
      assert(blink:enabled() and cmp:is_available())
      columns('blink', 'product_only', 'payment_only')
      columns('cmp', 'product_only', 'payment_only')
      eq(vim.fn['vim_dadbod_completion#omni'](1, ''), 9)
      assert(#vim.fn['vim_dadbod_completion#omni'](0, '') > 0)
    end
    vim.treesitter.get_parser = original
  end)

  -- Fail (not skip) when real parser prerequisites are absent.
  for _, lang in ipairs({ 'go', 'sql', 'python' }) do vim.treesitter.language.add(lang) end

  test('availability resolves real Go injections without fetching metadata', function()
    local bufnr = go()
    vim.b.db = 'postgresql://embedded/unique'
    after(6, 'p.')
    local count = #vim.g.test_connections
    local fetches = vim.g.test_table_fetches
    assert(blink:enabled() and cmp:is_available())
    eq(#vim.g.test_connections, count)
    eq(vim.g.test_table_fetches, fetches)
    local sql = assert(context.resolve())
    eq(sql.bufnr, bufnr)
    eq(sql.embedded, true)
    eq(sql.row, 1)
    eq(sql.col, 13)
    eq(sql.lines[1], '')
    eq(sql.lines[2], '    SELECT p.id, p.name')
    assert(not table.concat(sql.lines, '\n'):find('payments'))
    columns('blink', 'product_only', 'payment_only')
    eq(vim.g.test_connections[#vim.g.test_connections], { 'postgresql://embedded/unique', bufnr, 'go' })
    eq(vim.bo.filetype, 'go')
    eq(vim.b.dbui_db_key_name, nil)
  end)

  test('multiline and same-line alias isolation in Blink and cmp', function()
    go()
    for _, source in ipairs({ 'blink', 'cmp' }) do
      after(6, 'p.')
      columns(source, 'product_only', 'payment_only')
      after(11, 'p.')
      columns(source, 'payment_only', 'product_only')
      after(13, 'p.')
      columns(source, 'product_only', 'payment_only')
      after(11, 'p.')
      columns(source, 'payment_only', 'product_only')
    end
  end)

  test('table completion edits exclude host prefix and closing raw delimiter', function()
    go()
    after(15, 'pro')
    local cursor = vim.api.nvim_win_get_cursor(0)
    for _, source in ipairs({ 'blink', 'cmp' }) do
      local value = assert(item(complete(source), 'products'))
      eq(value.textEdit.range, {
        start = { line = 14, character = cursor[2] - 3 },
        ['end'] = { line = 14, character = cursor[2] },
      })
      local line = vim.api.nvim_get_current_line()
      local edit = value.textEdit
      eq(line:sub(1, edit.range.start.character) .. edit.newText .. line:sub(edit.range['end'].character + 1),
        '\ttables := `SELECT * FROM products`')
    end
  end)

  test('replacement in the middle of a SQL word stays inside the string', function()
    annotated('SELECT * FROM product')
    after(4, 'pro')
    for _, source in ipairs({ 'blink', 'cmp' }) do
      local edit = assert(item(complete(source), 'products')).textEdit
      local line = vim.api.nvim_get_current_line()
      eq(line:sub(1, edit.range.start.character) .. edit.newText .. line:sub(edit.range['end'].character + 1),
        'q := `SELECT * FROM products`')
    end
  end)

  test('annotation belongs only to the immediately following declaration', function()
    buffer('go', { 'package main', 'func f() {', '// language=SQL',
      'notSQL := 1', 'q := `SELECT pro`', '}' })
    after(5, 'pro')
    eq(context.resolve(), nil)
    eq(complete('blink'), {})
  end)

  test('no results in surrounding host code or unrecognized strings, even direct requests', function()
    go()
    for _, pos in ipairs({ { 16, 'pro' }, { 17, 'products' }, { 15, 'tables' }, { 4, 'SQL' } }) do
      after(pos[1], pos[2])
      assert(not blink:enabled() and not cmp:is_available())
      eq(complete('blink'), {})
      eq(complete('cmp'), {})
    end
  end)

  test('insertion-point boundaries at opening and closing delimiters', function()
    annotated('pro')
    local line = vim.api.nvim_buf_get_lines(0, 3, 4, false)[1]
    local opening = assert(line:find('`', 1, true)) - 1
    at(4, opening)
    eq(context.resolve(), nil)
    at(4, opening + 1)
    eq(assert(context.resolve()).col, 0)
    eq(complete('blink'), {})
    at(4, #line - 1) -- immediately BEFORE closing delimiter is inside
    assert(item(complete('blink'), 'products'))
    at(4, #line) -- immediately AFTER closing delimiter is outside
    eq(context.resolve(), nil)
    eq(complete('cmp'), {})
  end)

  test('incomplete SQL, including syntax ERROR nodes, is still eligible', function()
    annotated('SELECT p. FROM products p WHERE (')
    after(4, 'p.')
    columns('cmp', 'product_only', 'payment_only')
    annotated('SEL')
    after(4, 'SEL')
    assert(item(complete('blink'), 'SELECT'))
  end)

  test('editing SQL and moving regions never reuses stale text or aliases', function()
    go()
    after(13, 'p.')
    columns('blink', 'product_only', 'payment_only')
    vim.api.nvim_buf_set_lines(0, 12, 13, false, { '\tthird := `SELECT p. FROM payments p`' })
    after(13, 'p.')
    columns('blink', 'payment_only', 'product_only')
    after(6, 'p.')
    columns('cmp', 'product_only', 'payment_only')
    vim.api.nvim_buf_set_lines(0, 3, 4, false, { '\t// not SQL' })
    after(6, 'p.')
    eq(context.resolve(), nil)
    eq(complete('blink'), {})
  end)

  test('quoting, schema scope, host settings and metadata reuse', function()
    annotated('SELECT p."Or" FROM products p')
    after(4, 'p."Or')
    for _, source in ipairs({ 'blink', 'cmp' }) do
      eq(assert(item(complete(source), 'Order')).textEdit.newText, 'Order')
    end
    annotated('SELECT p.Or FROM products p')
    after(4, 'p.Or')
    eq(assert(item(complete('blink'), 'Order')).textEdit.newText, '"Order"')
    annotated('SELECT * FROM public.pro')
    after(4, 'public.pro')
    assert(item(complete('cmp'), 'products'))
    annotated('SELECT prod')
    vim.b.db_table = 'products'
    after(4, 'prod')
    assert(item(complete('blink'), 'product_only'))
    eq(vim.g.test_table_fetches, 2, 'metadata reused across host buffers')
    vim.fn['vim_dadbod_completion#clear_cache']()
    assert(item(complete('blink'), 'product_only'))
    eq(vim.g.test_table_fetches, 3)
  end)

  test('SQL punctuation and host-buffer bind parameters retain completion', function()
    annotated('SELECT id,pro')
    after(4, 'pro')
    assert(item(complete('cmp'), 'products'))
    annotated('SELECT * FROM products WHERE id = :par')
    vim.b.dbui_bind_params = { [':param'] = 'example value' }
    after(4, ':par')
    for _, source in ipairs({ 'blink', 'cmp' }) do
      local value = assert(item(complete(source), ':param'))
      eq(value.textEdit.newText, 'param')
      eq(value.documentation, 'example value')
      eq(value.textEdit.range.start.character, #'q := `SELECT * FROM products WHERE id = :')
    end
  end)

  test('Python injection: host-independent resolver and byte-based edits', function()
    buffer('python', vim.fn.readfile(root .. '/tests/fixtures/embedded.py'))
    after(1, 'p.')
    columns('blink', 'product_only', 'payment_only')
    columns('cmp', 'product_only', 'payment_only')
    after(3, 'pro')
    eq(complete('cmp'), {})
    buffer('python', { 'query = "SELECT é, pro"' })
    after(1, 'pro')
    for _, source in ipairs({ 'blink', 'cmp' }) do
      local edit = assert(item(complete(source), 'products')).textEdit
      eq(edit.range.start.character, #'query = "SELECT é, ')
      eq(edit.range['end'].character, #'query = "SELECT é, pro')
    end
    eq(cmp:get_position_encoding_kind(), 'utf-8')
  end)

  test('missing host parser, missing SQL parser and unavailable API fail closed', function()
    buffer('dadbod_no_parser', { 'SELECT pro' })
    after(1, 'pro')
    eq(context.resolve(), nil)
    eq(complete('blink'), {})
    annotated('SELECT pro')
    after(4, 'pro')
    local get_parser = vim.treesitter.get_parser
    vim.treesitter.get_parser = nil
    eq(context.resolve(), nil)
    eq(complete('cmp'), {})
    vim.treesitter.get_parser = get_parser
    local add = vim.treesitter.language.add
    vim.treesitter.language.add = function(lang, ...)
      if lang == 'sql' then error('SQL parser missing') end
      return add(lang, ...)
    end
    annotated('SELECT pro')
    after(4, 'pro')
    eq(context.resolve(), nil)
    vim.treesitter.language.add = add
  end)

  test('combined/disjoint injections are rejected, not merged', function()
    local query = [[
      ((raw_string_literal (raw_string_literal_content) @injection.content)
       (#set! injection.language "sql")
       (#set! injection.combined))
    ]]
    buffer('go', { 'package main', 'func f() {', 'a := `SELECT p. FROM products p`', 'b := `SELECT p. FROM payments p`', '}' })
    after(3, 'p.')
    local parser = vim.treesitter.get_parser(0, 'go', { injections = { go = query } })
    parser:parse(true)
    local ranges
    parser:for_each_tree(function(tree, lang)
      if lang:lang() == 'sql' then ranges = tree:included_ranges(false) end
    end)
    eq(#assert(ranges), 2, 'real combined SQL tree')
    eq(context.resolve(), nil)
    eq(complete('blink'), {})
  end)

  test('excluded interpolation content is not SQL', function()
    buffer('python', { 'query = f"SELECT {host_value} FROM products"' })
    local parser = vim.treesitter.get_parser(0, 'python', { injections = { python = [[
      ((string (string_content) @injection.content)
       (#set! injection.language "sql")
       (#set! injection.combined))
    ]] } })
    parser:parse(true)
    local ranges
    parser:for_each_tree(function(tree, lang)
      if lang:lang() == 'sql' then ranges = tree:included_ranges(false) end
    end)
    eq(#assert(ranges), 2, 'real SQL injection excludes the interpolation gap')
    after(1, 'host_val')
    eq(context.resolve(), nil)
    eq(complete('cmp'), {})
    after(1, 'SELECT')
    eq(context.resolve(), nil, 'disjoint query is unsupported even in its SQL portion')
  end)
  if vim.env.DADBOD_TEST_CMP and vim.env.DADBOD_TEST_BLINK then
    vim.opt.runtimepath:append(vim.env.DADBOD_TEST_CMP)
    vim.opt.runtimepath:append(vim.env.DADBOD_TEST_BLINK)
    test('real nvim-cmp source pipeline keeps UTF-8 edits within SQL', function()
      require('cmp').setup({ sources = { { name = 'vim-dadbod-completion' } } })
      buffer('python', { 'query = "SELECT é, product"' })
      after(1, 'pro')
      local source = require('cmp.source').new('vim-dadbod-completion', cmp)
      local ctx = require('cmp.context').new(nil, { reason = require('cmp.types').cmp.ContextReason.Manual })
      local done = false
      source:complete(ctx, function() done = true end)
      assert(vim.wait(1000, function() return done end), 'cmp callback timed out')
      local entry
      for _, e in ipairs(source.entries) do if e.completion_item.label == 'products' then entry = e end end
      assert(entry, 'cmp discarded products')
      eq(entry.replace_range.start.character, #'query = "SELECT é, ')
      eq(entry.replace_range['end'].character, #'query = "SELECT é, product')
    end)
    test('real Blink provider and edit pipeline preserve host delimiters', function()
      buffer('python', { 'query = "SELECT é, product"' })
      after(1, 'pro')
      local provider = require('blink.cmp.sources.lib.provider').new('dadbod', {
        name = 'Dadbod', module = 'vim_dadbod_completion.blink',
      })
      assert(provider:enabled())
      local cursor = vim.api.nvim_win_get_cursor(0)
      local items
      provider:get_completions({
        id = 1, bufnr = vim.api.nvim_get_current_buf(), cursor = cursor, line = vim.api.nvim_get_current_line(),
        bounds = { start_col = cursor[2] - 2, length = 3 }, trigger = { kind = 'manual', initial_kind = 'manual' },
      }, function(result) items = result end)
      local value = assert(item(assert(items), 'products'))
      local edit = require('blink.cmp.lib.text_edits').get_from_item(value)
      eq(edit.range.start.character, #'query = "SELECT é, ')
      eq(edit.range['end'].character, #'query = "SELECT é, product')
      vim.lsp.util.apply_text_edits({ edit }, vim.api.nvim_get_current_buf(), 'utf-8')
      eq(vim.api.nvim_get_current_line(), 'query = "SELECT é, products"')
    end)
  end

  test('documented Go query is exactly the real-parser fixture', function()
    local fixture = table.concat(vim.fn.readfile(root .. '/tests/fixtures/queries/go/injections.scm'), '\n')
    local readme = table.concat(vim.fn.readfile(root .. '/README.md'), '\n')
    eq(readme:match('```scheme\n(.-)\n```'), fixture)
    local help = table.concat(vim.fn.readfile(root .. '/doc/vim-dadbod-completion.txt'), '\n')
    local query = assert(help:match('>query\n(.-)\n<'))
    eq(query:gsub('^    ', ''):gsub('\n    ', '\n'), fixture)
  end)
  print('PASS: ' .. tests .. ' tests')
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd('cquit 1')
else
  vim.cmd('qa!')
end
