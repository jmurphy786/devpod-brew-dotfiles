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
      sources = {
        -- At a tag position in a notes vault, show only registered tags.
        default = function()
          if vim.bo.filetype == "markdown" and require("notes.util").buf_vault(0) then
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            local before = vim.api.nvim_get_current_line():sub(1, col)
            if require("notes.blink_tags").tag_start(0, row, before) then
              return { "notes_tags" }
            end
          end
          return { "lsp", "notes_tags", "path", "snippets", "buffer" }
        end,
        providers = {
          -- Registered tags only (lua/notes/tags.lua); see lua/notes/blink_tags.lua.
          notes_tags = { name = "Tags", module = "notes.blink_tags" },
          lsp = {
            -- In notes vaults, tags come from notes_tags: drop markdown-oxide's
            -- own #tag items (they include unregistered ones), and all of its
            -- items on the frontmatter tags line so `[` there isn't a link.
            transform_items = function(ctx, items)
              if vim.bo[ctx.bufnr].filetype ~= "markdown" or not require("notes.util").buf_vault(ctx.bufnr) then
                return items
              end
              local before = ctx.line:sub(1, ctx.cursor[2])
              local on_tags_line = require("notes.blink_tags").in_frontmatter_tags(ctx.bufnr, ctx.cursor[1], before)
              return vim.tbl_filter(function(item)
                if item.client_name ~= "markdown_oxide" then
                  return true
                end
                if on_tags_line then
                  return false
                end
                local text = item.filterText or (item.textEdit and item.textEdit.newText) or item.label
                return not (item.kind == 14 and text:sub(1, 1) == "#")
              end, items)
            end,
          },
        },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
}
