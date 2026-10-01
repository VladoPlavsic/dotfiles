return {
  {
    'lervag/vimtex',
    lazy = false,
    init = function()
      -- VimTeX configuration goes here, e.g.
      vim.g.vimtex_view_method = 'skim' -- or 'zathura' on Linux, 'general' for others
      vim.g.vimtex_compiler_method = 'latexmk'

      -- Disable insert mode mappings (let LSP/completion handle this)
      vim.g.vimtex_imaps_enabled = 0

      -- Enable quickfix auto open
      vim.g.vimtex_quickfix_mode = 1

      -- Suppress some compilation warnings
      vim.g.vimtex_quickfix_ignore_filters = {
        'Underfull \\hbox',
        'Overfull \\hbox',
        'LaTeX Warning: .\\+ float specifier changed to',
        'Package hyperref Warning: Token not allowed in a PDF string',
      }

      -- Completion (works with blink.cmp)
      vim.g.vimtex_complete_enabled = 1

      -- -- Syntax highlighting - works with treesitter
      -- vim.g.vimtex_syntax_enabled = 1

      -- Enable folding
      vim.g.vimtex_fold_enabled = 0

      -- PDF viewer settings for macOS (Skim)
      -- For Skim, you need to set Preferences > Sync > Check for file changes
      -- and set PDF-TeX Sync support to "Neovim"
      vim.g.vimtex_view_skim_sync = 1
      vim.g.vimtex_view_skim_activate = 1

      -- Compilation settings
      vim.g.vimtex_compiler_latexmk = {
        build_dir = '',
        callback = 1,
        continuous = 1,
        executable = 'latexmk',
        options = {
          '-pdf',
          '-verbose',
          '-file-line-error',
          '-synctex=1',
          '-interaction=nonstopmode',
        },
      }
    end,
    keys = {
      { '<leader>lc', '<cmd>VimtexCompile<cr>', desc = '[L]aTeX [C]ompile' },
      { '<leader>lv', '<cmd>VimtexView<cr>', desc = '[L]aTeX [V]iew PDF' },
      { '<leader>ls', '<cmd>VimtexStop<cr>', desc = '[L]aTeX [S]top compilation' },
      { '<leader>lt', '<cmd>VimtexTocOpen<cr>', desc = '[L]aTeX [T]able of contents' },
      { '<leader>le', '<cmd>VimtexErrors<cr>', desc = '[L]aTeX [E]rrors' },
      { '<leader>li', '<cmd>VimtexInfo<cr>', desc = '[L]aTeX [I]nfo' },
      { '<leader>lk', '<cmd>VimtexClean<cr>', desc = '[L]aTeX Clean auxiliary files' },
    },
  },
}
