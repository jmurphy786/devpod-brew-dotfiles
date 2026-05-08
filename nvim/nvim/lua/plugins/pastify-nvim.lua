return {
  "TobinPalmer/pastify.nvim",
  cmd = { "Pastify", "PastifyAfter" },
  event = { "BufReadPost" },
  opts = {
    opts = {
      absolute_path = false,
      local_path = "/images/",
      save = "local",
      filename = function()
        return os.date("%Y-%m-%d_%H-%M-%S")
      end,
      default_ft = "markdown",
    },
    ft = {
      markdown = "![]($IMG$)",
    },
  },
}
