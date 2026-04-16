vim.bo.expandtab = true
vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.shiftwidth = 2

vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldminlines = 0
vim.opt_local.foldlevel = 99
vim.opt_local.foldlevelstart = 99
vim.opt_local.foldenable = true
vim.opt_local.foldcolumn = "1"
