---@type blink.cmp.Source
local M = {}
local context = require('vim_dadbod_completion.context')

local map_kind_to_cmp_lsp_kind = {
  F = 3,  -- Function -> Function
  C = 5,  -- Column -> Field
  A = 6,  -- Alias -> Variable
  T = 7,  -- Table -> Class
  R = 14, -- Reserved -> Keyword
  S = 19, -- Schema -> Folder
}

function M.new()
  return setmetatable({}, { __index = M })
end

function M:get_trigger_characters()
  return { '"', '`', '[', ']', '.' }
end

function M:enabled()
  return context.resolve() ~= nil
end

function M:get_completions(ctx, callback)
  local transformed_callback = function(items)
    callback({
      context = ctx,
      is_incomplete_forward = true,
      is_incomplete_backward = true,
      items = items,
    })
  end

  local sql = context.resolve(ctx.bufnr, ctx.cursor)
  if not sql then
    transformed_callback({})
    return function() end
  end

  local results, range = context.complete(sql, ctx.cursor)
  local by_word = {}
  for _, item in ipairs(results) do
    local key = item.word..(item.kind or '')
    if by_word[key] == nil then
      by_word[key] = item
    end
  end
  local items = {} ---@type table<string,lsp.CompletionItem>

  for _, item in pairs(by_word) do
    table.insert(items, {
      label = item.abbr or item.word,
      dup = 0,
      insertText = item.word,
      -- Blink's non-LSP providers use UTF-8 byte positions.
      textEdit = { newText = item.word, range = range },
      labelDetails = item.menu and { description = item.menu } or nil,
      documentation = item.info or '',
      kind = map_kind_to_cmp_lsp_kind[item.kind] or vim.lsp.protocol.CompletionItemKind.Text
    })
  end

  transformed_callback(items)

  return function() end
end

return M
