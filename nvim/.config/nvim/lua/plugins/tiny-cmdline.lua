-- Floating, centered cmdline on top of Neovim 0.12's native ui2 cmdline window.
return {
  {
    "rachartier/tiny-cmdline.nvim",
    lazy = false, -- initialises itself on UIEnter
    init = function()
      -- ui2 is opt-in in 0.12; tiny-cmdline only repositions the window ui2 owns.
      pcall(function()
        require("vim._core.ui2").enable({})
      end)
      vim.o.cmdheight = 0 -- the plugin wants the bottom cmdline gone
    end,
    config = function()
      require("tiny-cmdline").setup({
        -- border is nil by default, which inherits vim.o.winborder ("rounded")
        native_types = { "/", "?" }, -- keep searches at the bottom
        on_reposition = require("tiny-cmdline").adapters.blink,
      })
    end,
  },
}

