return {
  "vhyrro/luarocks.nvim",
  enabled = vim.env.NVIM_PROFILE == "personal",
  priority = 1001,
  opts = { rocks = { "magick", "dkjson" } },
}
