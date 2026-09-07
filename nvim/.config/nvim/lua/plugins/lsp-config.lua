-- LSP servers are configured with the built-in vim.lsp.config/vim.lsp.enable
-- (Nvim 0.11+). Mason is only used to install the server binaries.
return {
  {
    "mason-org/mason.nvim",
    lazy = false,
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry", -- roslyn
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)

      -- roslyn is installed on demand (needs .NET); see lua/plugins/roslyn.lua
      local ensure_installed = {
        "typescript-language-server",
        "lua-language-server",
        "harper-ls",
        "markdown-oxide",
        "stylua",
        "roslyn",
        "prettier",
      }
      local registry = require("mason-registry")
      registry.refresh(function()
        for _, name in ipairs(ensure_installed) do
          local ok, pkg = pcall(registry.get_package, name)
          if ok and not pkg:is_installed() then
            pkg:install()
          end
        end
      end)

      local capabilities = require("blink.cmp").get_lsp_capabilities()

      vim.lsp.config("*", { capabilities = capabilities })

      vim.lsp.config("ts_ls", {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
        root_markers = { "tsconfig.json", "package.json" },
      })

      -- nvim-lspconfig is not installed, so every server needs a full config
      -- here; without `cmd` nvim rejects it with "expected executable command".
      vim.lsp.config("lua_ls", {
        cmd = { "lua-language-server" },
        filetypes = { "lua" },
        root_markers = { ".luarc.json", ".luarc.jsonc", ".stylua.toml", "stylua.toml", ".git" },
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("harper_ls", {
        cmd = { "harper-ls", "--stdio" }, -- without --stdio it listens on TCP :4000
        filetypes = { "markdown", "gitcommit" },
        root_markers = { ".git" },
      })

      vim.lsp.config("roslyn", {
        filetypes = { "cs" },
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
          ["csharp|formatting"] = {
            dotnet_organize_imports_on_format = true,
          },
        },
      })

      vim.lsp.config("markdown_oxide", {
        cmd = { "markdown-oxide" },
        filetypes = { "markdown" },
        -- Unnamed / scratch buffers make markdown-oxide panic ("file should have
        -- file stem") and quit with exit code 101, which kills go-to-definition
        -- for the rest of the session. Only attach to buffers backed by a file:
        -- not calling on_dir stops the client from starting.
        root_dir = function(bufnr, on_dir)
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name == "" or vim.bo[bufnr].buftype ~= "" then
            return
          end
          on_dir(vim.fs.root(bufnr, { ".moxide.toml", ".obsidian", ".git" }) or vim.fs.dirname(name))
        end,
        capabilities = vim.tbl_deep_extend("force", capabilities, {
          workspace = {
            didChangeWatchedFiles = { dynamicRegistration = true, relativePatternSupport = true },
          },
        }),
        on_attach = function()
          vim.api.nvim_create_user_command("Daily", function(args)
            vim.lsp.buf.execute_command({ command = "jump", arguments = { args.args } })
          end, { desc = "Open daily note", nargs = "*" })
        end,
      })

      vim.lsp.enable({ "ts_ls", "lua_ls", "harper_ls", "roslyn", "markdown_oxide" })

      -- Nvim 0.11 defaults already provide: K (hover), grn rename, gra code action,
      -- grr references, gri implementation, grt type definition, ]d / [d diagnostics.
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to definition" })
      vim.keymap.set("n", "<leader>gD", function()
        vim.cmd("rightbelow vsplit")
        vim.lsp.buf.definition()
      end, { desc = "Go to definition in vsplit" })
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
      vim.keymap.set("n", "<leader>.", vim.lsp.buf.hover, { desc = "Hover docs / definition" })
      vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
      vim.keymap.set("n", "<leader>lr", function()
        vim.lsp.stop_client(vim.lsp.get_clients({ bufnr = 0 }))
        vim.cmd("edit")
      end, { desc = "Restart LSP" })
    end,
  },
}
