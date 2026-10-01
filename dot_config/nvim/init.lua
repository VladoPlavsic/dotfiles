-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Add transperency
vim.opt.termguicolors = true

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Hide statusline (piped to tmux via tpipeline)
vim.opt.laststatus = 0
vim.o.cmdheight = 0

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option for OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 999

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier.
-- Otherwise, you normally need to press <C-\><C-n>.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Disable arrow keys in normal mode
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Line swapping up and down
vim.keymap.set('n', '<A-j>', '<cmd>:m +1<CR>')
vim.keymap.set('n', '<A-k>', '<cmd>:m -2<CR>')

-- Buffer switching
vim.keymap.set('n', '<Tab>', '<cmd>bn<cr>', { silent = true, desc = 'Next buffer' })
vim.keymap.set('n', '<S-Tab>', '<cmd>bp<cr>', { silent = true, desc = 'Previous buffer' })

-- Buffer delete without closing window
vim.keymap.set('n', '<leader>bd', '<cmd>bp|bd #<cr>', { silent = true, desc = 'Delete buffer and set previous' })

vim.keymap.set('n', 'gf', 'gF', { silent = true, desc = 'Go to file' })

vim.keymap.set('n', '<leader>yf', function()
  vim.cmd ':let @+=expand("%:p")'
end, { desc = 'Yank full path of current buffer' })

vim.keymap.set('n', '<leader>yr', function()
  vim.cmd ':let @+=expand("%")'
end, { desc = 'Yank relative path of current buffer' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
-- ATM stdpath(data) = ~/.local/share/nvim/
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

-- prepend lazy folder to [r]un[t]ime[p]ath a list of directories that Neovim searches for:
-- * plugins
-- * colorschemes
-- * syntax files
-- * ftplugins
-- * Lua modules in lua/ folders

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins run
--    :Lazy update
--
require('lazy').setup({
  -- Waka Time - track what you spend time on
  require 'lazy.vim-wakatime',
  -- Store commands to quick access (tome)
  require 'lazy.tome',
  require 'lazy.persistence',
  -- A hackable Markdown, HTML, LaTeX, Typst & YAML previewer for Neovim
  -- Full git cli support, I don't use any keybindings, use :Git and any known git command
  require 'lazy.vim-fugitive',
  require 'lazy.diffview',
  -- Some crazy stuff with notifications and nice command line
  -- require 'lazy.noice',
  -- Automatically detect the indentation style used in a buffer and updating the buffer options accordingly.
  require 'lazy.guess-indent',
  -- transparency
  require 'lazy.transparent',
  -- Neovim statusline (piped to tmux via tpipeline)
  --  require 'lazy.lualine',
  require 'lazy.tpipline',
  -- zen
  -- require 'lazy.zen-mode',
  -- Displays available keybindings in popup.
  require 'lazy.which-key',
  -- Extendable fuzzy finder over lists.
  require 'lazy.telescope',
  require 'lazy.grug-far',
  -- Neovim config lazy updating libraries
  require 'lazy.lazydev',
  -- Default Nvim LSP client configurations for various LSP servers.
  require 'lazy.nvim-lspconfig',
  -- Formatter
  require 'lazy.conform',
  -- Experimental library of neovim plugins with a focus on performance and simplicity (yes, I guess you can use plugin managers inside plugin managers)
  require 'lazy.blink',
  -- Theme
  -- require 'lazy.oceanic-next',
  require 'lazy.elixir-pastel-theme',
  -- require 'lazy.elixir-beam-theme',
  -- Syntax highlight for elixir files
  require 'lazy.vim-elixir',

  -- Highlight todo, notes, etc in comments
  require 'lazy.todo-comments',
  -- Another plugin manager
  require 'lazy.mini',
  -- Tree-sitter is a parser generator tool and an incremental parsing library.
  -- It can build a concrete syntax tree for a source file and efficiently update the syntax tree as the source file is edited
  require 'lazy.nvim-treesitter',
  -- Auto pair brackets
  require 'lazy.autopairs',
  --
  -- Debug Adapter Protocol client implementation for Neovim
  -- require 'lazy.debug',
  --
  -- Spellcheck
  require 'lazy.dirtytalks',
  -- Navigate code with search labels, enhanced character motions, and Treesitter integration.
  require 'lazy.flash',
  -- My plugin for opening floating terminal inside current window - it's laggy but for quick usage it's okay
  require 'lazy.floterminal',
  -- Deep buffer integration for Git
  require 'lazy.gitsigns',
  --
  -- require 'lazy.indent_line',
  --
  -- Buffer tree view
  require 'lazy.neo-tree',
  --
  --  An asynchronous linter plugin for Neovim (>= 0.9.5) complementary to the built-in Language Server Protocol support.
  require 'lazy.nvim-lint',
  -- neovim file explorer that lets you edit your filesystem like a normal Neovim buffer
  require 'lazy.oil',
  -- When combined with a set of tmux key bindings, the plugin will allow you to navigate seamlessly between vim and tmux splits using a consistent set of hotkeys.
  require 'lazy.tmux-navigator',
  require 'lazy.tmux-clipboard',
  -- A Vim wrapper for running tests on different granularities.
  require 'lazy.vim-test',
  -- Claude AI integration
  require 'lazy.claude-code',
  require 'lazy.antigravity',
  require 'lazy.99',
  -- LaTeX support
  require 'lazy.vimtex',

  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  ui = {
    -- If using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

require 'custom.statusline'
require('custom.terminal_autoresize').setup()
require('custom.agent_manager').setup()

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
