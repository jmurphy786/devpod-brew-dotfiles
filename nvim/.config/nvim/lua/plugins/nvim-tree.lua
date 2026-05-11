return {
  "nvim-tree/nvim-tree.lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  lazy = false,
  config = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    require("nvim-tree").setup({
      -- Performance optimizations for monorepos
      disable_netrw = true,
      hijack_netrw = true,
      
      view = {
        width = 30,
        debounce_delay = 50,  -- Reduce UI updates
      },
      
      renderer = {
        group_empty = true,
        highlight_git = false,  -- Disable git highlighting for speed
        icons = {
          git_placement = "after",
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = false,  -- Disable git icons for performance
          },
        },
      },
      
      -- Key performance settings
      diagnostics = {
        enable = false,  -- Disable diagnostics for speed
      },
      
      update_focused_file = {
        enable = true,  -- Don't auto-reveal files
        update_root = false,
      },
      
      git = {
        enable = false,  -- Disable git integration completely
        ignore = true,
      },
      
      filesystem_watchers = {
        enable = true,  -- Critical: disable file watching in monorepos
      },
      
      filters = {
        dotfiles = false,
        custom = { 
          "^.git$", 
          "^node_modules$", 
          "^bin$", 
          "^obj$",
          ".vs",
          "*.csproj.user",
          "^dist$",
          "^build$",
          "^.next$",
          "^coverage$",
        },
      },
      
      actions = {
        open_file = {
          quit_on_open = false,
          resize_window = false,  -- Don't resize on file open
          window_picker = {
            enable = false
          },
        },
      },
    })

    vim.keymap.set("n", "<leader>n", ":NvimTreeToggle<CR>", {})
    vim.keymap.set("n", "<leader>nf", ":NvimTreeFindFile<CR>", {})
  end,
}
