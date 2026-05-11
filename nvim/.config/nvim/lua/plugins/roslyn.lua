return {
  "seblyng/roslyn.nvim",
  ft = "cs",
  dependencies = { "mason-org/mason.nvim" },
  config = function()

    require("roslyn").setup({
      filewatching = "off",
    })
  end,
}
