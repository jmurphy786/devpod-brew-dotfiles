return {
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },
  {
    "saghen/blink.cmp",
    version = "1.*", -- release tag = prebuilt fuzzy matcher, no cargo needed
    event = "InsertEnter",
    dependencies = { "L3MON4D3/LuaSnip" },
    ---@module 'blink.cmp'
    opts = {
      snippets = { preset = "luasnip" },
      keymap = {
        -- <C-space> open, <C-n>/<C-p> select, <C-e> hide, <C-y> accept
        preset = "default",
        -- Enter accepts only when an item is explicitly selected (see
        -- list.selection.preselect below); with nothing selected `accept` is a
        -- no-op and this falls through to a plain newline / list continuation.
        ["<CR>"] = { "accept", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },
      completion = {
        list = { selection = { preselect = false } },
        documentation = { auto_show = true },
        menu = { border = "rounded" },
      },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
}
