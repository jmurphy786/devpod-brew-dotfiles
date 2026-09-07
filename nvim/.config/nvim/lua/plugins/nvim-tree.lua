return {
  "nvim-tree/nvim-tree.lua",
  lazy = false,
  keys = {
    { "<leader>n", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file tree" },
    { "<leader>nf", "<cmd>NvimTreeFindFile<cr>", desc = "Reveal file in tree" },
  },
  opts = {
    view = { width = 30, debounce_delay = 50 },
    renderer = {
      group_empty = true,
      highlight_git = false,
      icons = { show = { git = false } },
    },
    -- git/diagnostics off: large monorepos
    diagnostics = { enable = false },
    git = { enable = false, ignore = true },
    update_focused_file = { enable = true, update_root = false },
    filters = {
      dotfiles = false,
      custom = {
        "^.git$", "^node_modules$", "^bin$", "^obj$", ".vs", "*.csproj.user",
        "^dist$", "^build$", "^.next$", "^coverage$",
      },
    },
    actions = {
      open_file = {
        resize_window = false,
        window_picker = { enable = false },
      },
    },
  },
  init = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
  end,
}
