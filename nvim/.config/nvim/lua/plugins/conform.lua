return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    { "<leader>gf", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, mode = { "n", "v" }, desc = "Format buffer" },
  },
  opts = {
    formatters_by_ft = {
      -- No external formatter for C#: Roslyn formats it with the workspace
      -- .editorconfig (indent, new-line-before-brace, spacing), which no conform
      -- formatter reads. "prefer" keeps the LSP in charge regardless.
      cs = { lsp_format = "prefer" },
      lua = { "stylua" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
      markdown = { "prettier" },
      yaml = { "prettier" },
    },
    default_format_opts = { lsp_format = "fallback" },
  },
}
