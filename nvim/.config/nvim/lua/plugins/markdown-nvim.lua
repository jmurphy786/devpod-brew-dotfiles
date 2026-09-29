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

      -- o / O deliberately stay plain "open line": lists only continue on
      -- insert-mode <CR> while typing (see formatoptions in vim-options.lua).

      map("n", "<leader>x", "<Cmd>MDTaskToggle<CR>", "Toggle task")
      map("x", "<leader>x", ":MDTaskToggle<CR>", "Toggle task")
    end,
  },
}
