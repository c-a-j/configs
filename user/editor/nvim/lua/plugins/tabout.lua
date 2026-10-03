return {
  "abecodes/tabout.nvim",
  lazy = false,
  dependencies = {
    "saghen/blink.cmp",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    tabkey = "<Tab>",
    backwards_tabkey = "<S-Tab>",
    act_as_tab = true,
    act_as_shift_tab = true,
    -- Blink handles completion and snippets first, then falls back to these maps.
    -- Its completion menu is not Neovim's built-in popup menu.
    completion = false,
    ignore_beginning = true,
  },
}
