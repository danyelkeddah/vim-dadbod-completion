local M = {}
local supported = { sql = true, mysql = true, plsql = true }

local function contains(range, row, col)
  -- Cursor positions are insertion points: the end is valid immediately before
  -- a closing host delimiter, but the position after that delimiter is not.
  return (row > range[1] or row == range[1] and col >= range[2])
    and (row < range[3] or row == range[3] and col <= range[4])
end

local function injected_range(bufnr, row, col)
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then return end
  -- Parse incrementally, requesting injections on the cursor's line only.
  parser:parse({ row, row + 1 })
  local selected
  local function visit(ltree, depth)
    for _, tree in pairs(ltree:trees()) do
      -- A LanguageTree can contain several TSTrees (separate injections).
      -- Node ranges are unsuitable here: they can omit whitespace/error text.
      local ranges = tree:included_ranges(false)
      for _, range in ipairs(ranges) do
        if contains(range, row, col) and (not selected or depth > selected.depth) then
          selected = { depth = depth, lang = ltree:lang(), ranges = ranges }
        end
      end
    end
    for _, child in pairs(ltree:children()) do visit(child, depth + 1) end
  end
  visit(parser, 0)
  if selected and selected.depth > 0 and supported[selected.lang] and #selected.ranges == 1 then
    return selected.ranges[1]
  end
end

---Resolve SQL at an insertion point. All coordinates are zero-based bytes.
---No database access or context cache; Tree-sitter maintains its incremental trees.
---@param bufnr? integer
---@param cursor? integer[] {one-based row, zero-based byte column}
---@return table|nil
function M.resolve(bufnr, cursor)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local row, col = cursor[1] - 1, cursor[2]
  if supported[vim.bo[bufnr].filetype] then
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if not line then return end
    return { bufnr = bufnr, embedded = false, line = line, col = col, row = row, line_offset = 0 }
  end
  if vim.fn.has('nvim-0.10') == 0 or not vim.treesitter then return end
  -- Missing parsers/queries/APIs and transient parse failures are not typing errors.
  local ok, range = pcall(injected_range, bufnr, row, col)
  if not ok or not range then return end
  local text_ok, lines = pcall(vim.api.nvim_buf_get_text, bufnr, range[1], range[2], range[3], range[4], {})
  if not text_ok then return end
  local local_row = row - range[1]
  local offset = local_row == 0 and range[2] or 0
  return {
    bufnr = bufnr,
    embedded = true,
    range = range,
    lines = lines,
    row = local_row,
    col = col - offset,
    line = lines[local_row + 1] or '',
    line_offset = offset,
  }
end

---Use the core's SQL prefix rules, not the host completion engine's keyword range.
---Returns results and a host-buffer byte range for explicit completion edits.
function M.complete(context, cursor)
  local start = vim.fn['vim_dadbod_completion#omni'](1, '', context)
  if start < 0 then
    -- Engines also request keywords after SQL punctuation (e.g. commas or
    -- bind-parameter colons), which the public omnifunc findstart may reject.
    local prefix = context.line:sub(1, context.col):match('[%w_]*$') or ''
    start = context.col - #prefix
  end
  local base = context.line:sub(start + 1, context.col)
  local items = vim.fn['vim_dadbod_completion#omni'](0, base, context)
  return items, {
    start = { line = cursor[1] - 1, character = start + context.line_offset },
    ['end'] = {
      line = cursor[1] - 1,
      character = cursor[2] + #(context.line:sub(context.col + 1):match('^[%w_]*') or ''),
    },
  }
end

return M
