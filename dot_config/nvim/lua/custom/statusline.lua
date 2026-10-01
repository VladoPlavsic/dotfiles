local M = {}

local mode_map = {
  n = 'NORMAL  ',
  i = 'INSERT  ',
  v = 'VISUAL  ',
  V = 'V-LINE  ',
  ['\22'] = 'V-BLOCK ',
  c = 'COMMAND ',
  s = 'SELECT  ',
  S = 'S-LINE  ',
  R = 'REPLACE ',
  t = 'TERMINAL',
}

function M.mode()
  return mode_map[vim.api.nvim_get_mode().mode] or 'UNKNOWN'
end

function M.branch()
  local b = vim.b.gitsigns_head or vim.fn.FugitiveHead()
  if b and b ~= '' then
    return ' ' .. b .. ' |'
  end
  return ''
end

function M.filename()
  local name = vim.fn.expand '%:t'
  if name == '' then
    return '[No Name]'
  end
  if vim.bo.modified then
    name = name .. ' [+]'
  end
  return name
end

function M.filetype_info()
  local enc = vim.o.fileencoding ~= '' and vim.o.fileencoding or vim.bo.fileformat
  return enc .. ' :: ' .. vim.bo.fileformat .. ' :: ' .. vim.bo.filetype
end

function M.progress()
  local cur = vim.fn.line '.'
  local total = vim.fn.line '$'
  if cur == 1 then
    return 'Top'
  end
  if cur == total then
    return 'Bot'
  end
  return string.format('%2d%%%%', math.floor(cur / total * 100))
end

function M.location()
  return string.format('%d:%d', vim.fn.line '.', vim.fn.col '.')
end

vim.opt.statusline = table.concat {
  ' %{%v:lua.require("custom.statusline").mode()%} |',
  ' %{%v:lua.require("custom.statusline").branch()%}',
  '%< %{%v:lua.require("custom.statusline").filename()%} |',
  '%=',
  ' %{%v:lua.require("custom.statusline").filetype_info()%} ',
  ' %{%v:lua.require("custom.statusline").progress()%} ',
  ' %{%v:lua.require("custom.statusline").location()%} ',
}

return M
