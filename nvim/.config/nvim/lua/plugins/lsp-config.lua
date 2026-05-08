return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "ts_ls",  -- TypeScript
        "lua_ls", -- Lua
        "harper_ls"
      },
      automatic_enable = {
        exclude = { "roslyn_ls" }, -- prevent auto-enable, roslyn.nvim handles this
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
      "neovim/nvim-lspconfig",
    },

    registries = {
      "github:mason-org/mason-registry",
      "github:Crashdummyy/mason-registry",
    },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- TypeScript
      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
      })

      vim.lsp.config("roslyn", {
        capabilities = capabilities,
        cmd = {
          "/home/jordan/.local/share/nvim/mason/bin/roslyn",
          "--logLevel=Debug", -- changed from Information
          "--extensionLogDirectory=/home/jordan/.local/state/nvim",
          "--stdio",
        },
        settings = {
          ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles",
            dotnet_compiler_diagnostics_scope = "openFiles",
          },
        },
      })

      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
      })

      vim.lsp.config('markdown_oxide', {
        capabilities = vim.tbl_deep_extend(
          'force',
          capabilities,
          {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          }
        ),
        on_attach = function(client, bufnr)
          if client.name == "markdown_oxide" then
            vim.api.nvim_create_user_command(
              "Daily",
              function(args)
                vim.lsp.buf.execute_command({ command = "jump", arguments = { args.args } })
              end,
              { desc = "Open daily note", nargs = "*" }
            )
          end
        end,
      })

      vim.lsp.enable('markdown_oxide') -- Enable LSPs
      vim.lsp.enable("lua_ls")
      vim.lsp.enable("ts_ls")
      vim.lsp.enable("harper_ls")

      -- Keymaps
      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})

      vim.keymap.set("n", "<leader>gd", function()
        vim.lsp.buf.definition()
      end, { desc = "Go to definition" })

      vim.keymap.set("n", "<leader>gD", function()
        vim.cmd("rightbelow vsplit")
        vim.lsp.buf.definition()
      end, { desc = "Go to definition in vertical split" })
      vim.keymap.set({ "n" }, "<leader>ca", vim.lsp.buf.code_action, {})
    end,
  },
}
