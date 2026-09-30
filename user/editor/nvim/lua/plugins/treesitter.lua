-- Parsers installed up front. Anything else installs on demand when a
-- buffer with a supported filetype is opened (see FileType autocmd below).
local langs = {
  "bash",
  "c",
  "cpp",
  "javascript",
  "lua",
  "query",
  "markdown",
  "markdown_inline",
  "python",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local max_filesize = 100 * 1024 -- 100 KB

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    ts.setup()
    ts.install(langs)

    local function start(buf, lang)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
      if ok and stats and stats.size > max_filesize then
        return
      end
      pcall(vim.treesitter.start, buf, lang)
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter-auto", { clear = true }),
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang or not vim.tbl_contains(ts.get_available(), lang) then
          return
        end
        if vim.tbl_contains(ts.get_installed(), lang) then
          start(args.buf, lang)
        else
          ts.install(lang):await(function()
            start(args.buf, lang)
          end)
        end
      end,
    })
  end,
}
