-- Notifies LSP servers about files renamed/moved/deleted from nvim-tree,
-- so imports get updated.
return {
  "antosha417/nvim-lsp-file-operations",
  event = "LspAttach",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-tree.lua" },
  opts = {},
}
