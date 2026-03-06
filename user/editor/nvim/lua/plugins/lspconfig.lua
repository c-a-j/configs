return {
  "neovim/nvim-lspconfig",
  config = function()
    -- Basic LSP setup with common keybindings
    local on_attach = function(client, bufnr)
      -- Enable completion triggered by <c-x><c-o>
      vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

      -- Mappings
      local opts = { noremap = true, silent = true, buffer = bufnr }
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
      vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
      vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
      vim.keymap.set('n', '<leader>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, opts)
      vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
      vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
      vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
      vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts)
    end

    -- Configure language servers using the new vim.lsp.config API
    vim.lsp.config('lua_ls', {
      on_attach = on_attach,
      settings = {
        Lua = {
          runtime = {
            version = 'LuaJIT',
          },
          diagnostics = {
            globals = { 'vim' },
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true),
          },
          telemetry = {
            enable = false,
          },
        },
      },
    })
    
    -- Enable the language server
    vim.lsp.enable('lua_ls')

    -- Python
    vim.lsp.config('pyright', {
      on_attach = on_attach,
    })
    vim.lsp.enable('pyright')

    -- Bash
    vim.lsp.config('bashls', {
      on_attach = on_attach,
    })
    vim.lsp.enable('bashls')

    -- TypeScript
    vim.lsp.config('tsserver', {
      on_attach = on_attach,
    })
    vim.lsp.enable('tsserver')

    -- C/C++ (clangd provides diagnostics/linting; ClangTidy adds extra checks)
    vim.lsp.config('clangd', {
      on_attach = on_attach,
      cmd = {
        'clangd',
        '--background-index',
        '--clang-tidy',
        '--header-insertion=iwyu',
        '--completion-style=bundled',
      },
      filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
      root_markers = { 'compile_commands.json', 'compile_flags.txt', '.clangd' },
      capabilities = {
        offsetEncoding = { 'utf-16' },
      },
    })
    vim.lsp.enable('clangd')
    -- Rust
    vim.lsp.config('rust_analyzer', {
      on_attach = on_attach,
    })
    vim.lsp.enable('rust_analyzer')
  end,
}
