return {
  "saghen/blink.cmp",
  -- Pin to a release tag so lazy downloads the prebuilt Rust fuzzy-matcher
  -- binary instead of needing a local `cargo build`.
  version = "1.*",
  dependencies = { "rafamadriz/friendly-snippets" },
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- super-tab: <Tab> accepts the suggestion (Copilot-style ghost text),
    -- <C-space> opens/toggles the menu, <C-e> dismisses, <C-k> signature.
    keymap = { preset = "super-tab" },

    appearance = { nerd_font_variant = "mono" },

    completion = {
      -- Inline grey preview of the top match, shown even when nothing in the
      -- menu is selected. <Tab> accepts it.
      ghost_text = { enabled = true, show_without_selection = true },

      -- Menu is toggle-only: it never auto-pops. Summon the full list with
      -- <C-space>, then <C-n>/<C-p> (or arrows) to move through it.
      menu = { auto_show = false },

      -- Nothing pre-highlighted or auto-inserted until you explicitly accept.
      list = {
        selection = { preselect = false, auto_insert = false },
      },

      -- Docs popup only appears after a short pause, not instantly.
      documentation = { auto_show = true, auto_show_delay_ms = 250 },
    },

    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },

    signature = { enabled = true },

    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
