-- Don't try to be vi compatible
vim.o.compatible = false

-- Helps force plugins to load correctly when it is turned back on
vim.cmd("filetype on")

vim.o.autoindent = true
vim.cmd("filetype indent on")
vim.o.smartindent = true

-- turn off auto comment insertion
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  command = "setlocal formatoptions-=c formatoptions-=r formatoptions-=o"
})

-- Turn on syntax highlighting
vim.cmd("syntax on")

-- Fold Method
vim.o.foldmethod = "marker"

-- Security
vim.o.modelines = 0


-- Show line numbers
vim.o.number = true

-- Show cursor position (line and column)
vim.o.ruler = true

-- Status Bar Colors
vim.api.nvim_set_hl(0, "StatusLine", { ctermbg = 7, ctermfg = 8 })

-- Whitespace
vim.o.wrap = false
vim.o.textwidth = 80
vim.o.formatoptions = "lcqrn1" -- the l option does not automatically wrap, use gq
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.softtabstop = 2
vim.o.expandtab = true
vim.o.shiftround = false

-- Text Width Color Column
vim.o.colorcolumn = "81"
vim.cmd("highlight ColorColumn ctermbg=8")
vim.api.nvim_set_hl(0, "ColorColumn", { ctermbg = 8 })

-- Cursor motion
vim.o.scrolloff = 3
vim.o.backspace = "indent,eol,start"
vim.o.matchpairs = "(:),{:},[:],<:>"
vim.cmd("runtime! macros/matchit.vim")

-- Move up/down editor lines
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

-- Allow hidden buffers
vim.o.hidden = true

-- Status bar
vim.o.laststatus = 2

-- Last line
vim.o.showmode = true
vim.o.showcmd = true

-- Searching
vim.keymap.set("n", "/", "/\\v")
vim.keymap.set("v", "/", "/\\v")
vim.o.hlsearch = true
vim.o.incsearch = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.keymap.set("n", "<leader><space>", ":let @/=''<cr>", { desc = "clear search" })

-- Highlight matching brackets and change the color scheme
vim.o.showmatch = true
vim.api.nvim_set_hl(0, "MatchParen", {
  bg = "red",  -- or use a color name/hex
  italic = true
})

-- Formatting
vim.keymap.set("n", "<leader>q", "gqip")

-- Visualize tabs and newlines
vim.o.listchars = "tab:▸ ,eol:¬"
-- Uncomment this to enable by default:
-- vim.o.list = true -- To enable by default
-- Or use your leader key + l to toggle on/off
vim.keymap.set("n", "<leader>l", ":set list!<CR>", { desc = "Toggle tabs and EOL" })

-- Custom File Types
-- autocmd BufNewFile,BufRead *.EXTENSION set filetype=FT
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.vimrc.bak",
  command = "set filetype vim"
})
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*.gohtml",
  command = "set syntax=html"
})

-- {{{ VISUAL MODE MAPPINGS

-- Search and replace
vim.keymap.set("v", "\\sr", ":s/\\%V{s}/{r}/g <bar> :noh")

-- ! True/False switch
vim.keymap.set("v", "\\tf", ":s/\\%Vtrue/false/g <bar> :noh")
vim.keymap.set("v", "\\ft", ":s/\\%Vfalse/true/g <bar> :noh")

-- Auto indent
vim.keymap.set("v", "\\i", ":ggVG= <bar> :noh")

-- default commenting is #
vim.keymap.set("v", "\\c", ":s/^/# / <bar> :noh")
vim.keymap.set("v", "\\u", ":s/# \\?// <bar> :noh")

-- Line Commenting
vim.api.nvim_create_autocmd("FileType", {
  pattern = "sh",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/# / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/# \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "perl",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/# / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/# \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "vim",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/\" / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\" \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/\\/\\/ / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\/ \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/\\/\\/ / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\/ \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tmux",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/# / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/# \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "conf",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/# / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/# \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "json",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/\\/\\/ / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\/ \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "scss",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^\\(.*\\)$/\\/\\* \\1 \\*\\// <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\* \\?\\(.*\\) \\?\\*\\//\\1/ <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "css",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^\\(.*\\)$/\\/\\* \\1 \\*\\// <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\* \\?\\(.*\\) \\?\\*\\//\\1/ <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "html",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^\\(.*\\)$/<!-- \\1 -->/ <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/<!-- \\?\\(.*\\) \\?-->\\/\\1/ <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "javascript",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/\\/\\/ / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\/ \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "typescript",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/\\/\\/ / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\/ \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "typescriptreact",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/\\/\\/ / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/\\/\\/ \\?// <bar> :noh", { buffer = 0 })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function()
    vim.keymap.set("v", "\\c", ":s/^/% / <bar> :noh", { buffer = 0 })
    vim.keymap.set("v", "\\u", ":s/% \\?// <bar> :noh", { buffer = 0 })
  end
})
-- }}}

-- {{{ Templates
local template_dir = "~/.config/nvim/templates"
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*_test.go",
  command = "0r " .. template_dir .."/skel.test.go"
})
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*(test)@<!.go",
  command = "0r " .. template_dir .."/skel.go"
})
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*.sh",
  command = "0r " .. template_dir .."/skel.sh"
})
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*.pl",
  command = "0r " .. template_dir .."/skel.pl"
})
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*.py",
  command = "0r " .. template_dir .."/skel.py"
})
-- }}}

-- {{{ File specific settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "yaml",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.autoindent = false
    vim.cmd("filetype indent off")
  end
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "toml",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
    vim.bo.shiftwidth = 2
  end
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.bo.softtabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
  end
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.bo.spell = true
  end
})
-- }}}

-- Turn off annoyances
vim.keymap.set({ "n", "v" }, "Q", "<Nop>")
vim.o.visualbell = true
vim.cmd("set t_vb=")

-- Disable mouse
vim.o.mouse = ""

-- Disable Arrow keys in normal mode
vim.keymap.set("n", "<up>", "<Nop>")
vim.keymap.set("n", "<down>", "<Nop>")
vim.keymap.set("n", "<left>", "<Nop>")
vim.keymap.set("n", "<right>", "<Nop>")

-- Disable Arrow keys in insert mode
vim.keymap.set("i", "<up>", "<Nop>")
vim.keymap.set("i", "<down>", "<Nop>")
vim.keymap.set("i", "<left>", "<Nop>")
vim.keymap.set("i", "<right>", "<Nop>")

-- Disable Arrow keys in visual mode
vim.keymap.set("v", "<up>", "<Nop>")
vim.keymap.set("v", "<down>", "<Nop>")
vim.keymap.set("v", "<left>", "<Nop>")
vim.keymap.set("v", "<right>", "<Nop>")

-- Plugins
require("config.lazy")

-- gruvbox
vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme gruvbox]])
