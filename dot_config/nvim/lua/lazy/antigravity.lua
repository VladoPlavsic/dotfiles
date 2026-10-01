return {
  'NakLast/antigravity-cli.nvim',
  config = function()
    vim.api.nvim_set_hl(0, 'AntigravityNormal', { bg = 'none' })
    vim.api.nvim_set_hl(0, 'AntigravityBorder', { bg = 'none' })

    -- The window is recreated on every toggle, so reapply highlights whenever the terminal is shown
    vim.api.nvim_create_autocmd({ 'TermOpen', 'BufWinEnter' }, {
      pattern = 'term://*agy*',
      callback = function()
        vim.wo.winhighlight = 'Normal:AntigravityNormal,FloatBorder:AntigravityBorder'
      end,
    })

    require('antigravity').setup {
      cmd = 'agy',
      -- Plugin defaults to 'vsplit'; any other value opens a centered float
      style = 'float',
      width_ratio = 0.9,
      height_ratio = 0.9,
      border = 'rounded',
    }
  end,
}
