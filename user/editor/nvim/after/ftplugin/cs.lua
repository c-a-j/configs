vim.bo.expandtab = true
vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.shiftwidth = 2
-- Continuation after unclosed "(" indents one shiftwidth (default is 2s).
-- U1: honor continuation indentation on lines beginning with parentheses, including lambdas.
-- J1: JS/C#-style object literals, m1: align ")" with line of matching "("
vim.bo.cinoptions = "J1,(s,m1,U1"
