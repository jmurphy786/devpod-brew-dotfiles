return {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("trouble").setup({
      auto_close = true,  -- Auto close when you jump to an item
      auto_preview = true,  -- Show preview
      focus = true,  -- Focus trouble window when opened
      follow = true,  -- Follow current item
      
      modes = {
        lsp_references = {
          params = {
            include_declaration = false,  -- Don't include the declaration
          },
        },
      },
      
      -- Make files more noticeable
      icons = {
        indent = {
          top = "│ ",
          middle = "├╴",
          last = "└╴",
          fold_open = " ",
          fold_closed = " ",
          ws = "  ",
        },
        folder_closed = " ",
        folder_open = " ",
      },
      
      -- Easy close keybinds
      keys = {
        ["q"] = "close",
        ["<esc>"] = "close",
        ["<cr>"] = "jump_close",  -- Jump to item and close
        ["o"] = "jump_close",  -- Alternative
        ["<tab>"] = "jump",  -- Jump but keep window open
      },
    })
    
    -- Keybindings
    vim.keymap.set("n", "<leader>gr", "<cmd>Trouble lsp_references<cr>", { desc = "LSP References" })
    vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
    vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer Diagnostics" })
    
    -- These work when you actually have items in location/quickfix list
    vim.keymap.set("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List" })
    vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List" })
  end,
}
