return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "ts_ls",
        "lua_ls",
        "harper_ls",
      },
      automatic_enable = {
        exclude = { "roslyn" },
      },
    },
    dependencies = {
      {
        "mason-org/mason.nvim",
        opts = {
          registries = {
            "github:mason-org/mason-registry",
            "github:Crashdummyy/mason-registry",
          }
        },
      },
    },
    config = function(_, opts)
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      require("mason-lspconfig").setup(opts)

      vim.lsp.config("ts_ls", { capabilities = capabilities })
      vim.lsp.config("lua_ls", { capabilities = capabilities })
      vim.lsp.config("harper_ls", { capabilities = capabilities })
      vim.lsp.config("roslyn", {
        capabilities = capabilities,
        filetypes = {"cs"},
        cmd = {
          vim.fn.stdpath("data") .. "/mason/bin/roslyn",
          "--logLevel=Debug",
          "--extensionLogDirectory=" .. vim.fn.stdpath("log"),
          "--stdio",
        },
        settings = {
          ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles",
            dotnet_compiler_diagnostics_scope = "openFiles",
          },
        },
      })
      vim.lsp.config("markdown_oxide", {
        capabilities = vim.tbl_deep_extend("force", capabilities, {
          workspace = {
            didChangeWatchedFiles = { dynamicRegistration = true },
          },
        }),
        on_attach = function(client, bufnr)
          if client.name == "markdown_oxide" then
            vim.api.nvim_create_user_command("Daily", function(args)
              vim.lsp.buf.execute_command({ command = "jump", arguments = { args.args } })
            end, { desc = "Open daily note", nargs = "*" })
          end
        end,
      })

      vim.lsp.enable("ts_ls")
      vim.lsp.enable("lua_ls")
      vim.lsp.enable("harper_ls")
      vim.lsp.enable("roslyn")
      vim.lsp.enable("markdown_oxide")

      -- Keymaps
      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to definition" })
      vim.keymap.set("n", "<leader>gD", function()
        vim.cmd("rightbelow vsplit")
        vim.lsp.buf.definition()
      end, { desc = "Go to definition in vertical split" })
      vim.keymap.set({ "n" }, "<leader>ca", vim.lsp.buf.code_action, {})

      -- Restart LSP keymap since LspRestart won't exist
      vim.keymap.set("n", "<leader>lr", function()
        vim.lsp.stop_client(vim.lsp.get_clients({ bufnr = 0 }))
        vim.cmd("e")
      end, { desc = "Restart LSP" })
    end,
  },
}
