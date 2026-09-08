return {
  "Mofiqul/vscode.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    vim.o.background = "dark"
    local c = require("vscode.colors").get_colors()

    require("vscode").setup({
      transparent = true,
      italic_comments = true,
      italic_inlayhints = true,
      underline_links = true,
      disable_nvimtree_bg = true,
      terminal_colors = true,
      group_overrides = {
        Cursor = { fg = c.vscDarkBlue, bg = c.vscLightGreen, bold = true },
      },
    })

    vim.cmd.colorscheme("vscode")
  end,
}
