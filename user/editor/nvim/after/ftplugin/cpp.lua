vim.bo.expandtab = true
vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.shiftwidth = 2
-- (s: continuation after an unclosed "(" indents one shiftwidth.
-- u0: do not add another shiftwidth for each extra paren opened on the same line.
-- U1: honor that indent even when the line starts with "(".
-- m1: align closing ")" with the line of the matching "(".
-- k2s: "if"/"for"/"while" condition continuations indent two shiftwidths
--      so they stand apart from the body that follows.
vim.bo.cinoptions = "(s,u0,U1,m1,k2s"
