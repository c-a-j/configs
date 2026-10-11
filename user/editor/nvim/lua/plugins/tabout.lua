-- Tab in insert mode: indent the line when only whitespace precedes the
-- cursor, otherwise tab out of the surrounding pair. Tabout's own fallback
-- cannot tell these apart: with the cursor on the first character of a
-- multi-line call it scans the line text and jumps to its end instead of
-- indenting, so the keys are mapped here and tabout only provides <Plug>s.
local function at_line_start()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(1, col):match("^%s*$") ~= nil
end

return {
  "abecodes/tabout.nvim",
  lazy = false,
  dependencies = {
    "saghen/blink.cmp",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    tabkey = "",
    backwards_tabkey = "",
    act_as_tab = true,
    act_as_shift_tab = true,
    -- Blink handles completion and snippets first, then falls back to these maps.
    -- Its completion menu is not Neovim's built-in popup menu.
    completion = false,
    ignore_beginning = true,
  },
  config = function(_, opts)
    require("tabout").setup(opts)
    vim.keymap.set("i", "<Tab>", function()
      return at_line_start() and "<C-t>" or "<Plug>(Tabout)"
    end, { expr = true, remap = true, silent = true })
    vim.keymap.set("i", "<S-Tab>", function()
      return at_line_start() and "<C-d>" or "<Plug>(TaboutBack)"
    end, { expr = true, remap = true, silent = true })
  end,
}
