return {
  'nvim-telescope/telescope.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'debugloop/telescope-undo.nvim',
    'nvim-telescope/telescope-ui-select.nvim',  -- Add this line
  },
  config = function()
    -- Enable persistent undo
    vim.opt.undofile = true
    vim.opt.undodir = vim.fn.stdpath('cache') .. '/undo'
    vim.fn.mkdir(vim.fn.stdpath('cache') .. '/undo', 'p')
    vim.opt.undolevels = 10000
    vim.opt.undoreload = 10000

    local builtin = require('telescope.builtin')
    
    require('telescope').setup({
      defaults = {
        file_ignore_patterns = {
          "node_modules",
          ".git/",
          "bin/",
          "obj/",
        },
        layout_config = {
          horizontal = {
            preview_width = 0.55,
          },
        },
      },
      pickers = {
        find_files = {
          hidden = true,  -- Show hidden files
        },
      },
      extensions = {
        undo = {
          use_delta = true,
          side_by_side = true,
          layout_strategy = "vertical",
          layout_config = {
            preview_height = 0.8,
          },
          mappings = {
            i = {
              ["<CR>"] = require("telescope-undo.actions").restore,
              ["<C-y>"] = require("telescope-undo.actions").yank_additions,
              ["<C-d>"] = require("telescope-undo.actions").yank_deletions,
            },
            n = {
              ["<CR>"] = require("telescope-undo.actions").restore,
              ["y"] = require("telescope-undo.actions").yank_additions,
              ["d"] = require("telescope-undo.actions").yank_deletions,
            },
          },
        },
      -- Add this section
        ["ui-select"] = {
          require("telescope.themes").get_dropdown {
            -- You can customize more here if needed
          }
        },
      },
    })

    -- Load extensions
    require('telescope').load_extension('undo')
    require('telescope').load_extension('ui-select')  -- Add this line

    -- Keybindings
    vim.keymap.set('n', '<leader>p', builtin.find_files, { desc = "Find files" })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = "Live grep" })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = "Buffers" })
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = "Help tags" })
    vim.keymap.set('n', '<leader>u', '<cmd>Telescope undo<cr>', { desc = "Undo history" })
  end,
}
