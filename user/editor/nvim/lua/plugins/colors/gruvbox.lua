return { 
  "sainnhe/gruvbox-material",
  lazy = false,
  priority = 1000, 
  config = function()
    vim.g.gruvbox_material_background = 'medium'  -- 'hard', 'medium', or 'soft'
    vim.g.gruvbox_material_palette = 'material'  -- 'material', 'mix', or 'original'
    vim.g.gruvbox_material_enable_italic = true
    vim.g.gruvbox_material_enable_bold = true
    vim.g.gruvbox_material_transparent_background = true
    vim.g.gruvbox_material_ui_contrast = 'high'  -- 'low', 'medium', or 'high'
    vim.cmd.colorscheme('gruvbox-material')
  end
}
