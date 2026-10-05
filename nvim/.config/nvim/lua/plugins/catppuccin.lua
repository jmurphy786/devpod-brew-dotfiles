-- Opaque catppuccin for markdown buffers; vscode (transparent) everywhere else.
-- Colorschemes are global, so this swaps on BufEnter/FileType.
return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 900, -- below vscode (1000) so it never becomes the startup theme
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      transparent_background = false,
      integrations = {
        render_markdown = true,
        treesitter = true,
        blink_cmp = true,
        native_lsp = { enabled = true },
        telescope = { enabled = true },
        nvimtree = true,
      },
    })

    -- Markdown highlight tweaks; reapplied whenever catppuccin loads (a
    -- colorscheme load clears custom highlights).
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("MarkdownHighlights", { clear = true }),
      pattern = "catppuccin*",
      callback = function()
        local set_hl = vim.api.nvim_set_hl
        set_hl(0, "@markup.heading.1.markdown", { fg = "#f38ba8", bold = true })
        set_hl(0, "@markup.strong", { fg = "#fab387", bold = true })
        set_hl(0, "@markup.italic", { fg = "#cba6f7", italic = true })
        set_hl(0, "@markup.raw.markdown_inline", { fg = "#a6e3a1", bg = "#313244" })
        set_hl(0, "@markup.link.label", { fg = "#89b4fa", underline = true })
        set_hl(0, "@markup.list", { fg = "#94e2d5" })
        -- merge so the opaque background survives (set_hl replaces the group)
        local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        set_hl(0, "Normal", vim.tbl_extend("force", normal, { fg = "#cdd6f4" }))
      end,
    })

    local current = "vscode"
    local function set(name)
      if current == name then
        return
      end
      current = name
      vim.cmd.colorscheme(name)
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
      group = vim.api.nvim_create_augroup("MarkdownTheme", { clear = true }),
      nested = true, -- let ColorScheme fire so other plugins refresh their highlights
      callback = function(ev)
        -- skip terminals (the :Glow float), quickfix, floats etc.
        if vim.bo[ev.buf].buftype ~= "" then
          return
        end
        if vim.api.nvim_win_get_config(0).relative ~= "" then
          return
        end
        set(vim.bo[ev.buf].filetype == "markdown" and "catppuccin-mocha" or "vscode")
      end,
    })
  end,
}
