return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = { "tadmccorkle/markdown.nvim" },
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup({
      ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "tsx", "html", "typescript", "javascript", "c_sharp" },
      highlight = { enable = true },
      indent = { enable = true },
    })
  end
}
