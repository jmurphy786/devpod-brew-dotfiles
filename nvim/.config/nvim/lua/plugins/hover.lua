return {
	"lewis6991/hover.nvim",
	config = function()
		require("hover").setup({
			init = function()
				require("hover.providers.lsp")
				require("hover.providers.diagnostic")
			end,
			preview_opts = {
				border = "rounded",
			},
			preview_window_opts = {
				winblend = 100, -- No transparency, solid look
			},
			title = true,
		})

		-- Custom styling

		vim.keymap.set("n", "<leader>.", require("hover").hover, { desc = "hover.nvim" })
	end,
}
