-- Markdown editing: list continuation, checkbox toggle, TOC, heading motions.
-- Replaces bullets.vim.
return {
  "tadmccorkle/markdown.nvim",
  ft = "markdown",
  opts = {
    mappings = {
      -- `gs` would swallow mini.surround's `gsa`/`gsd`/`gsr` in markdown buffers
      inline_surround_toggle = false,
      inline_surround_toggle_line = false,
      inline_surround_delete = false,
      inline_surround_change = false,
    },
    on_attach = function(bufnr)
      local list = require("markdown.list")
      local md_ts = require("markdown.treesitter")
      local map = function(mode, lhs, rhs, desc, opts)
        vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { buffer = bufnr, desc = desc }, opts or {}))
      end

      -- Same node lookup `insert_list_item` uses (markdown/list.lua), so the
      -- answer always agrees with what the plugin is about to do.
      local function in_list_item()
        local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
        if not ok or not parser then
          return false
        end
        parser:parse()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        local col = vim.fn.col("$") - 1
        return md_ts.find_node(function(node)
          return node:type() == "list_item"
        end, { pos = { row, col } }) ~= nil
      end

      -- Insert-mode <CR> is an expr mapping on purpose: blink.cmp owns <CR> and
      -- runs a plain callback through vim.schedule(), which lands the newline
      -- *after* whatever is typed next. An expr mapping is evaluated inline, so
      -- the newline keeps its place in the input stream.
      map("i", "<CR>", function()
        if in_list_item() then
          -- buffer edits are forbidden inside an expr mapping
          vim.schedule(function()
            list.insert_list_item_below()
          end)
          return ""
        end
        return vim.keycode("<CR>")
      end, "New list item below / newline", { expr = true })

      -- Normal mode does not go through blink, so a direct call is fine here.
      -- The list functions return false outside a list item; fall back to the
      -- built-in key ("n" = no remap, "i" = ahead of any queued keys).
      local function fallback(key)
        vim.api.nvim_feedkeys(vim.keycode(key), "ni", false)
      end
      map("n", "o", function()
        if not list.insert_list_item_below() then
          fallback("o")
        end
      end, "New list item below / open line")
      map("n", "O", function()
        if not list.insert_list_item_above() then
          fallback("O")
        end
      end, "New list item above / open line")

      map("n", "<leader>x", "<Cmd>MDTaskToggle<CR>", "Toggle task")
      map("x", "<leader>x", ":MDTaskToggle<CR>", "Toggle task")
    end,
  },
}
