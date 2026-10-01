return {
  'greggh/claude-code.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim', -- Required for git operations
  },
  config = function()
    vim.api.nvim_set_hl(0, 'ClaudeNormal', { bg = 'none' })
    vim.api.nvim_set_hl(0, 'ClaudeBorder', { bg = 'none' })

    vim.api.nvim_create_autocmd('TermOpen', {
      pattern = '*claude*',
      callback = function()
        vim.wo.winhighlight = 'Normal:ClaudeNormal,FloatBorder:ClaudeBorder'
      end,
    })

    require('claude-code').setup {
      window = {
        position = 'float',
        start_in_normal_mode = true,
        float = {
          width = '90%',
          height = '90%',
          row = 'center',
          col = 'center',
          border = 'rounded',
        },
      },
      keymaps = {
        toggle = {
          normal = false,
          terminal = false,
          variants = {
            continue = false,
            verbose = false,
          },
        },
        window_navigation = false, -- handled by float-aware tmux-navigator to keep popup focused
        scrolling = true,
      },
    }
  end,
}
