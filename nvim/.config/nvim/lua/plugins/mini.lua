-- Small mini.nvim modules, each installed standalone (not the whole suite).
return {
  {
    "nvim-mini/mini.icons",
    lazy = false,
    priority = 900,
    config = function()
      require("mini.icons").setup()
      MiniIcons.mock_nvim_web_devicons() -- nvim-tree / trouble / telescope
    end,
  },
  {
    "nvim-mini/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },
  {
    "nvim-mini/mini.pairs",
    event = "InsertEnter",
    opts = {},
  },
}
