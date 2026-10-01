local M = {}

local last_normal_win = nil

--- Get all floating windows in the current tabpage
function M.get_floating_windows()
  local floats = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ok, config = pcall(vim.api.nvim_win_get_config, win)
    if ok and config.relative and config.relative ~= '' then
      table.insert(floats, win)
    end
  end
  return floats
end

--- Check if a window is a floating window
function M.is_floating(win)
  win = win or vim.api.nvim_get_current_win()
  local ok, config = pcall(vim.api.nvim_win_get_config, win)
  return ok and config.relative and config.relative ~= ''
end

--- Focus a floating window, or toggle back to the previous regular window
function M.focus_float()
  local current_win = vim.api.nvim_get_current_win()
  local floats = M.get_floating_windows()

  -- If currently inside a floating window:
  if M.is_floating(current_win) then
    -- Find current index in floats
    local current_idx = nil
    for i, w in ipairs(floats) do
      if w == current_win then
        current_idx = i
        break
      end
    end

    -- If there is more than one float, cycle to the next float
    if current_idx and #floats > 1 then
      local next_idx = (current_idx % #floats) + 1
      local target_win = floats[next_idx]
      pcall(vim.api.nvim_win_set_config, target_win, { focusable = true })
      pcall(vim.api.nvim_set_current_win, target_win)
      return
    end

    -- Otherwise, jump back to the previous normal window
    if last_normal_win and vim.api.nvim_win_is_valid(last_normal_win) and not M.is_floating(last_normal_win) then
      vim.api.nvim_set_current_win(last_normal_win)
    else
      vim.cmd('wincmd p')
    end
    return
  end

  -- We are in a regular window:
  last_normal_win = current_win

  if #floats == 0 then
    vim.notify('No floating windows found', vim.log.levels.INFO)
    return
  end

  -- Target the last (most recently opened / topmost) floating window
  local target_win = floats[#floats]

  -- Ensure it is focusable even if LSP / plugin created it with focusable = false
  pcall(vim.api.nvim_win_set_config, target_win, { focusable = true })
  local ok = pcall(vim.api.nvim_set_current_win, target_win)
  if not ok then
    vim.notify('Failed to focus floating window', vim.log.levels.WARN)
    return
  end

  -- Attach convenient close keymaps to the floating buffer
  local buf = vim.api.nvim_win_get_buf(target_win)
  local buftype = vim.bo[buf].buftype
  if buftype ~= 'terminal' then
    vim.keymap.set('n', 'q', function()
      if vim.api.nvim_win_is_valid(target_win) then
        pcall(vim.api.nvim_win_close, target_win, false)
      end
    end, { buffer = buf, silent = true, nowait = true, desc = 'Close floating window' })

    vim.keymap.set('n', '<Esc>', function()
      if vim.api.nvim_win_is_valid(target_win) then
        pcall(vim.api.nvim_win_close, target_win, false)
      end
    end, { buffer = buf, silent = true, nowait = true, desc = 'Close floating window' })
  end
end

--- Close the current floating window, or the topmost floating window
function M.close_float()
  local current_win = vim.api.nvim_get_current_win()
  if M.is_floating(current_win) then
    pcall(vim.api.nvim_win_close, current_win, false)
    return
  end

  local floats = M.get_floating_windows()
  if #floats == 0 then
    vim.notify('No floating windows to close', vim.log.levels.INFO)
    return
  end

  local target_win = floats[#floats]
  pcall(vim.api.nvim_win_close, target_win, false)
end

--- Close all non-terminal floating windows in current tab
function M.close_all_floats()
  local floats = M.get_floating_windows()
  local closed = 0
  for _, win in ipairs(floats) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local buftype = vim.bo[buf].buftype
      if buftype ~= 'terminal' then
        pcall(vim.api.nvim_win_close, win, false)
        closed = closed + 1
      end
    end
  end
  if closed > 0 then
    vim.notify('Closed ' .. closed .. ' floating window(s)', vim.log.levels.INFO)
  end
end

function M.setup()
  -- <C-w>f and <C-w><C-f> to focus/toggle floating window
  vim.keymap.set('n', '<C-w>f', M.focus_float, { desc = 'Focus floating window' })
  vim.keymap.set('n', '<C-w><C-f>', M.focus_float, { desc = 'Focus floating window' })

  -- <leader>w shortcuts
  vim.keymap.set('n', '<leader>wf', M.focus_float, { desc = '[W]indow: [F]ocus float' })
  vim.keymap.set('n', '<leader>wc', M.close_float, { desc = '[W]indow: [C]lose float' })
  vim.keymap.set('n', '<leader>wX', M.close_all_floats, { desc = '[W]indow: Close all floats' })
end

return M
