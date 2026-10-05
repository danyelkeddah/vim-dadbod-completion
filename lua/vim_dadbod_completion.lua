local M = {}

function M.getCompletionItems(prefix, score_func)
  local items = vim.api.nvim_call_function('vim_dadbod_completion#omni',{0, prefix})
  for _, item in pairs(items) do
    item.user_data = vim.json.encode({ hover = item.info })
    item.dup = 0
  end

  return items
end

M.complete_item = {
  item = M.getCompletionItems
}

local nvim_cmp_source = {}
local context = require('vim_dadbod_completion.context')

---Source constructor.
nvim_cmp_source.new = function()
  local self = setmetatable({}, { __index = nvim_cmp_source })
  return self
end

nvim_cmp_source.get_debug_name = function()
  return 'vim-dadbod-completion'
end

function nvim_cmp_source:is_available()
  return context.resolve() ~= nil
end

function nvim_cmp_source:get_position_encoding_kind()
  return 'utf-8'
end

function nvim_cmp_source:get_trigger_characters(_)
  return { '"', '`', '[', ']', '.' }
end

local map_kind_to_cmp_lsp_kind = {
  F = 3,  -- Function -> Function
  C = 5,  -- Column -> Field
  A = 6,  -- Alias -> Variable
  T = 7,  -- Table -> Class
  R = 14, -- Reserved -> Keyword
  S = 19, -- Schema -> Folder
}

function nvim_cmp_source:complete(params, callback)
  local cursor = { params.context.cursor.row, params.context.cursor.col - 1 }
  local sql = context.resolve(params.context.bufnr, cursor)
  if not sql then
    callback({ items = {}, isIncomplete = true })
    return
  end
  local results, range = context.complete(sql, cursor)
  local items = {}
  for _, item in ipairs(results) do
    table.insert(items, {
      label = item.abbr,
      dup = 0,
      insertText = item.word,
      textEdit = { newText = item.word, range = range },
      labelDetails = {
        description = item.menu,
      },
      documentation = item.info,
      kind = map_kind_to_cmp_lsp_kind[item.kind],
    })
  end

  callback({
    items = items,
    isIncomplete = true
  })
end

M.nvim_cmp_source = nvim_cmp_source.new()

return M
