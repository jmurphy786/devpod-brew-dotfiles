return {
  "3rd/image.nvim",
  build = false,
  enabled = vim.env.NVIM_PROFILE == "personal",
  opts = {
    processor = "magick_rock",
    backend = "sixel",  -- WezTerm supports sixel
    integrations = {
      markdown = {
        enabled = true,
        only_render_image_at_cursor = true,  -- better performance
        only_render_image_at_cursor_mode = "popup",
        filetypes = { "markdown" },
      },
    },
    max_height_window_percentage = 50,
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.svg" },
  },
}
