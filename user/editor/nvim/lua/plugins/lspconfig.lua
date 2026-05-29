return {
  "neovim/nvim-lspconfig",
  config = function()
    -- LSP keybindings via LspAttach autocmd
    vim.api.nvim_create_autocmd('LspAttach', {
      callback = function(ev)
        local bufnr = ev.buf
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client then
          return
        end

        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

        local opts = { noremap = true, silent = true, buffer = bufnr }
        local function map(lhs, rhs)
          vim.keymap.set('n', lhs, rhs, opts)
        end
        local function map_if_supported(method, lhs, rhs)
          if client:supports_method(method, bufnr) then
            map(lhs, rhs)
          end
        end

        map_if_supported('textDocument/declaration', 'gD', vim.lsp.buf.declaration)
        map_if_supported('textDocument/definition', 'gd', vim.lsp.buf.definition)
        map_if_supported('textDocument/hover', 'K', vim.lsp.buf.hover)
        map_if_supported('textDocument/implementation', 'gi', vim.lsp.buf.implementation)
        map_if_supported('textDocument/signatureHelp', '<C-k>', vim.lsp.buf.signature_help)
        vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
        vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
        vim.keymap.set('n', '<leader>wl', function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, opts)
        map_if_supported('textDocument/typeDefinition', '<leader>D', vim.lsp.buf.type_definition)
        map_if_supported('textDocument/rename', '<leader>rn', vim.lsp.buf.rename)
        map_if_supported('textDocument/codeAction', '<leader>ca', vim.lsp.buf.code_action)
        map_if_supported('textDocument/references', 'gr', vim.lsp.buf.references)
        map('ee', vim.diagnostic.open_float)

        -- Inlay hints (inline type annotations): off by default, <leader>th toggles.
        if client:supports_method('textDocument/inlayHint', bufnr) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
          end)
        end
      end,
    })

    -- Configure language servers using the new vim.lsp.config API
    vim.lsp.config('lua_ls', {
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

    -- Python (basedpyright: open-source pyright fork that also serves inlay hints)
    vim.lsp.config('basedpyright', {
      settings = {
        basedpyright = {
          analysis = {
            -- Global default for projects without their own pyrightconfig.json.
            -- Per-project config (e.g. typeCheckingMode) overrides this.
            typeCheckingMode = "standard",
            inlayHints = {
              variableTypes = true,
              functionReturnTypes = true,
              callArgumentNames = true,
              pytestParameters = true,
            },
          },
        },
      },
    })
    vim.lsp.enable('basedpyright')

    -- Python linter (ruff provides diagnostics/autofixes; pairs with pyright for types)
    vim.lsp.config('ruff', {
      on_attach = function(client)
        -- Defer hover to pyright
        client.server_capabilities.hoverProvider = false
      end,
    })
    vim.lsp.enable('ruff')

    -- Bash
    vim.lsp.config('bashls', {
    })
    vim.lsp.enable('bashls')

    -- TypeScript
    vim.lsp.config('tsserver', {
    })
    vim.lsp.enable('tsserver')

    -- C/C++ (clangd provides diagnostics/linting; ClangTidy adds extra checks)
    vim.lsp.config('clangd', {
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
    })
    vim.lsp.enable('rust_analyzer')

    -- C#
    vim.lsp.config('roslyn_ls', {
      cmd = { vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'bin', 'roslyn-language-server'), '--stdio' },
    })
    vim.lsp.enable('roslyn_ls')
  end,
}
