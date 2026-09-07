-- nvim-treesitter `main` branch: no setup() options - parsers are installed
-- explicitly, and highlighting is started per-buffer with vim.treesitter.start().
-- Nvim bundles c/lua/markdown/query/vim/vimdoc parsers; the rest need the
-- `tree-sitter` CLI and a C compiler (brew install tree-sitter gcc).
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local parsers = {
      "c", "c_sharp", "html", "javascript", "json", "lua", "markdown",
      "markdown_inline", "query", "tsx", "typescript", "vim", "vimdoc",
    }

    if vim.fn.executable("tree-sitter") == 1 then
      local installed = require("nvim-treesitter.config").get_installed("parsers")
      local missing = vim.tbl_filter(function(p)
        return not vim.tbl_contains(installed, p)
      end, parsers)
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
        if lang and vim.tbl_contains(parsers, lang) and pcall(vim.treesitter.start, args.buf, lang) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
