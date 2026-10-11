vim.bo.expandtab = true
vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.shiftwidth = 2
-- (s: continuation after an unclosed "(" indents one shiftwidth (default is 2s).
-- u0: do not add another shiftwidth for each extra paren opened on the same line.
-- k2s: "if"/"for"/"while" condition continuations indent two shiftwidths.
-- U1: honor continuation indentation on lines beginning with parentheses, including lambdas.
-- J1: JS/C#-style object literals, m1: align ")" with line of matching "("
-- i0: avoid base-class alignment on the blank line before an opening brace.
vim.bo.cinoptions = "J1,(s,u0,m1,U1,i0,k2s"
