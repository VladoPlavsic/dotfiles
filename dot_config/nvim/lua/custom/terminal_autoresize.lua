local M = {}

--- Safely pulses terminal pty size to send SIGWINCH, forcing CLI apps (Claude Code, Gemini/Antigravity, etc.) to repaint
function M.redraw_terminal(win, buf)
  win = win or vim.api.nvim_get_current_win()
  buf = buf or (vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win))
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if vim.bo[buf].buftype ~= 'terminal' then
    return
  end

  local job_id = vim.b[buf].terminal_job_id
  if not job_id then
    return
  end

  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)
  if width <= 0 or height <= 0 then
    return
  end

  -- Resize pulse: changing dimensions by 1 and reverting forces the OS PTY driver
  -- to emit SIGWINCH, causing CLI applications (React/Ink, Bubbletea, curses) to repaint
  pcall(vim.fn.jobresize, job_id, width + 1, height)
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.fn.jobresize, job_id, width, height)
      vim.cmd('redraw!')
    end
  end, 25)
end

--- Resize all active floating terminal windows to 90% centered on screen
function M.resize_all_floating_terminals()
  local columns = vim.o.columns
  local lines = vim.o.lines

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local config = vim.api.nvim_win_get_config(win)
      if config.relative ~= '' then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
          local width = math.max(10, math.floor(columns * 0.9))
          local height = math.max(5, math.floor(lines * 0.9))
          local col = math.floor((columns - width) / 2)
          local row = math.floor((lines - height) / 2)

          vim.api.nvim_win_set_config(win, {
            relative = 'editor',
            width = width,
            height = height,
            row = row,
            col = col,
          })

          M.redraw_terminal(win, buf)
        end
      end
    end
  end
end

--- Setup ergonomic scroll mode keymaps for terminal buffers
function M.setup_terminal_scroll_keymaps(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- In Terminal mode (typing into prompt):
  -- <C-s>: Toggle scroll mode (enters Normal mode and scrolls half-page up into output)
  vim.keymap.set('t', '<C-s>', [[<C-\><C-n><C-u>]], { buffer = buf, silent = true, desc = 'Enter scroll mode' })

  -- <C-u>: Scrolls half page up directly into output
  vim.keymap.set('t', '<C-u>', [[<C-\><C-n><C-u>]], { buffer = buf, silent = true, desc = 'Scroll up half-page' })

  -- <C-b> and <PageUp>: Scroll full page up directly into output
  vim.keymap.set('t', '<C-b>', [[<C-\><C-n><C-b>]], { buffer = buf, silent = true, desc = 'Scroll up full-page' })
  vim.keymap.set('t', '<PageUp>', [[<C-\><C-n><PageUp>]], { buffer = buf, silent = true, desc = 'Scroll up page' })

  -- In Normal mode (navigating output):
  -- <C-s>: Return to prompt at the bottom in input mode
  vim.keymap.set('n', '<C-s>', 'G<Cmd>startinsert<CR>', { buffer = buf, silent = true, desc = 'Return to input mode' })

  -- q: Return to prompt at the bottom in input mode (like less / tmux copy-mode)
  vim.keymap.set('n', 'q', 'G<Cmd>startinsert<CR>', { buffer = buf, silent = true, desc = 'Return to input mode' })
end

function M.setup()
  local group = vim.api.nvim_create_augroup('FloatingTerminalAutoResize', { clear = true })

  -- 1. When tmux pane or terminal window is resized / maximized
  vim.api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = function()
      M.resize_all_floating_terminals()
    end,
    desc = 'Auto-resize floating terminal windows on tmux pane resize / zoom',
  })

  -- 2. When any terminal buffer is displayed or opened: attach scroll keymaps and redraw
  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'TermOpen' }, {
    group = group,
    pattern = 'term://*',
    callback = function(args)
      M.setup_terminal_scroll_keymaps(args.buf)

      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_is_valid(win) then
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= '' then
          -- Give the window a moment to settle, then redraw cleanly
          vim.defer_fn(function()
            if vim.api.nvim_win_is_valid(win) then
              M.redraw_terminal(win, args.buf)
            end
          end, 20)
        end
      end
    end,
    desc = 'Setup scroll mode and redraw terminal when floating window opens',
  })

  -- 3. Manual redraw shortcut (<leader>tr)
  vim.keymap.set({ 'n', 't' }, '<leader>tr', function()
    M.resize_all_floating_terminals()
    vim.cmd('echo "Terminal redrawn"')
  end, { silent = true, desc = '[T]erminal [r]edraw' })
end

return M
