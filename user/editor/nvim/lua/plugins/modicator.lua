return {
  "mawkler/modicator.nvim",
  lazy = false,
  dependencies = {
    "sainnhe/gruvbox-material",
    "nvim-lualine/lualine.nvim",
  },
  init = function()
    vim.o.termguicolors = true
    vim.o.number = true
    vim.o.cursorline = true
    -- Highlight only the line number, without shading the entire cursor line.
    vim.o.cursorlineopt = "number"
  end,
  opts = {
    integration = {
      lualine = {
        enabled = true,
        mode_section = "a",
        highlight = "bg",
      },
    },
  },
}
