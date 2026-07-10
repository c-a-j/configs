return {
  {
    "williamboman/mason.nvim",
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "lua-language-server",
        "basedpyright",
        "ruff",
        "bash-language-server",
        "typescript-language-server",
        "clangd",
        "rust-analyzer",
        "roslyn",
      },
      run_on_start = true,
    },
  },
}
