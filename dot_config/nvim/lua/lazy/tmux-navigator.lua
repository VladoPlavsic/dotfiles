local function tmux_navigate(direction)
  -- If currently inside a floating window (Gemini, Claude Code, etc.),
  -- navigating with wincmd would jump to the background editor buffer.
  -- Instead, directly tell tmux to switch to the adjacent pane so the
  -- floating window remains active when switching back.
  local is_floating = vim.api.nvim_win_get_config(0).relative ~= ''
  if is_floating and vim.env.TMUX then
    local tmux_dir = { h = '-L', j = '-D', k = '-U', l = '-R', ['\\'] = '-l' }
    local flag = tmux_dir[direction]
    if flag then
      vim.fn.system('tmux select-pane ' .. flag)
      return
    end
  end

  local cmd_map = {
    h = 'TmuxNavigateLeft',
    j = 'TmuxNavigateDown',
    k = 'TmuxNavigateUp',
    l = 'TmuxNavigateRight',
    ['\\'] = 'TmuxNavigatePrevious',
  }
  local cmd = cmd_map[direction]
  if cmd then
    vim.cmd(cmd)
  end
end

return {
  {
    'christoomey/vim-tmux-navigator',
    lazy = false,
    init = function()
      -- Must be set in `init` so it takes effect BEFORE the plugin is sourced,
      -- preventing broken Vim 8 tnoremap mappings from being installed.
      vim.g.tmux_navigator_no_mappings = 1
    end,
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
      'TmuxNavigatorProcessList',
    },
    keys = {
      {
        '<C-h>',
        function()
          tmux_navigate 'h'
        end,
        mode = { 'n', 't' },
        silent = true,
        desc = 'Tmux left',
      },
      {
        '<C-j>',
        function()
          tmux_navigate 'j'
        end,
        mode = { 'n', 't' },
        silent = true,
        desc = 'Tmux down',
      },
      {
        '<C-k>',
        function()
          tmux_navigate 'k'
        end,
        mode = { 'n', 't' },
        silent = true,
        desc = 'Tmux up',
      },
      {
        '<C-l>',
        function()
          tmux_navigate 'l'
        end,
        mode = { 'n', 't' },
        silent = true,
        desc = 'Tmux right',
      },
      {
        '<C-\\>',
        function()
          tmux_navigate '\\'
        end,
        mode = { 'n', 't' },
        silent = true,
        desc = 'Tmux previous',
      },
    },
    config = function()
      -- Automatically restore insert mode when returning to any terminal buffer
      vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
        callback = function()
          if vim.bo.buftype == 'terminal' then
            vim.cmd 'startinsert'
          end
        end,
      })
    end,
    opts = {},
  },
}
