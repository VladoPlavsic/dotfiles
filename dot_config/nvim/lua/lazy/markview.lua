-- This plugin makes use of tree-sitter queries! So, it must be loaded before nvim-treesitter.

-- You can solve this issue by loading this plugin as a dependency of nvim-treesitter(add dependencies = { "OXY2DEV/markview.nvim" } to your config for nvim-treesitter in lazy.nvim) and disable lazy-loading for both of the plugins.

-- So I did, we don't load this plugin on it's own
-- see ./nvim-treesitter.lua

return {
  {
    'OXY2DEV/markview.nvim',
  },
}
