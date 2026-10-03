return {
  "nvim-lualine/lualine.nvim",
  lazy = false,
  opts = {
    options = {
      theme = "auto",
      icons_enabled = false,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      globalstatus = false,
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {},
      lualine_c = { { "filename", file_status = true, path = 1 } },
      lualine_x = {},
      lualine_y = {},
      lualine_z = { "location" },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { { "filename", file_status = true, path = 1 } },
      lualine_x = {},
      lualine_y = {},
      lualine_z = { "location" },
    },
  },
  config = function(_, opts)
    require("lualine").setup(opts)
    -- The statusline already displays the current mode.
    vim.o.showmode = false
  end,
}
