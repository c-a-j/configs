return {
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    -- Optional dependencies
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    config = function()
      require("oil").setup {
        columns = { "icon" },
        keymaps = {
          ["<C-h>"] = false,
          ["<M-h>"] = "actions.select_split",
          ["<C-p>"] = {
            "actions.preview",
            opts = { vertical = true, split = "belowright" },
          },
        },
        float = {
          preview_split = "right",
        },
        view_options = {
          show_hidden = true,
        },
      }
      -- Open the preview after Oil renders, regardless of how the browser opens.
      local preview_pending = false
      local function open_default_preview(buf)
        vim.schedule(function()
          if vim.api.nvim_get_current_buf() ~= buf
            or vim.bo.filetype ~= "oil"
            or vim.wo.previewwindow
            or preview_pending
            or not require("oil").get_cursor_entry()
          then
            return
          end
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.wo[win].previewwindow then
              return
            end
          end
          preview_pending = true
          require("oil").open_preview({ vertical = true, split = "belowright" }, function()
            preview_pending = false
          end)
        end)
      end
      local group = vim.api.nvim_create_augroup("OilDefaultPreview", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "OilEnter",
        callback = function(args)
          open_default_preview(args.data.buf)
        end,
      })
      vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(args)
          if vim.bo[args.buf].filetype == "oil" then
            open_default_preview(args.buf)
          end
        end,
      })

      -- Open the parent directory in the current window.
      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

      -- Open the parent directory in a floating window.
      vim.keymap.set("n", "<space>-", require("oil").toggle_float,
        { desc = "Toggle floating parent directory" })
    end,
  },
}
