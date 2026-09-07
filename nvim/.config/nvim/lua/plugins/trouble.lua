return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
    { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
    { "<leader>gr", "<cmd>Trouble lsp_references<cr>", desc = "LSP references" },
    { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list" },
    { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
  },
  opts = {
    auto_close = false, -- don't vanish when the list momentarily empties
    auto_preview = true,
    focus = true,
    follow = true,
    modes = {
      lsp_references = { params = { include_declaration = false } },
    },
    keys = {
      ["q"] = "close",
      ["<esc>"] = "close",
      ["<cr>"] = "jump",       -- jump, keep the list open
      ["<tab>"] = "jump_only",
      ["o"] = "jump_close",    -- jump and dismiss
    },
  },
}
