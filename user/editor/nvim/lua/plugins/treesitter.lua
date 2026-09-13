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
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup()
    require("nvim-treesitter").install(langs)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = langs,
      callback = function(args)
        local max_filesize = 100 * 1024 -- 100 KB
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(args.buf))
        if ok and stats and stats.size > max_filesize then
          return
        end
        vim.treesitter.start(args.buf)
      end,
    })
  end,
}
