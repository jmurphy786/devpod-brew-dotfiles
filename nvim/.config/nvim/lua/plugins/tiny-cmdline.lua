-- Floating, centered cmdline on top of Neovim 0.12's native ui2 cmdline window.
return {
  {
    "rachartier/tiny-cmdline.nvim",
    lazy = false, -- initialises itself on UIEnter
    config = function()
      vim.o.cmdheight = 0 -- the plugin wants the bottom cmdline gone
      require("tiny-cmdline").setup({
        -- border is nil by default, which inherits vim.o.winborder ("rounded")
        native_types = { "/", "?" }, -- keep searches at the bottom
      })
    end,
  },
}
