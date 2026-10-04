return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-file-browser.nvim',
    'nvim-telescope/telescope-fzf-native.nvim', 
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release --target install'
  },
  config = function()
    require('telescope').setup {
      pickers = {
        find_files = {
          theme = "ivy"
        }
      },
      extensions = {
        file_browser = {
          hijack_netrw = false,
          hidden = true,
          layout_strategy = "horizontal",
          layout_config = {
            preview_cutoff = 0,
            preview_width = 0.5,
          },
        },
      },
    }
    require('telescope').load_extension('file_browser')
    vim.keymap.set("n", "<space>ff", require('telescope.builtin').find_files)
    vim.keymap.set("n", "<space>fg", require('telescope.builtin').live_grep)
    vim.keymap.set("n", "<space>fb", require('telescope.builtin').buffers)
    vim.keymap.set("n", "<space>fe", function()
      require('telescope').extensions.file_browser.file_browser {
        path = "%:p:h",
        select_buffer = true,
      }
    end, { desc = "Browse files with Telescope" })
    vim.keymap.set("n", "<space>fh", require('telescope.builtin').help_tags)
    vim.keymap.set("n", "<space>en", function()
      require('telescope.builtin').find_files {
        cwd = vim.fn.stdpath("config")
      }
    end)
  end
}
