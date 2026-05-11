local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.env.DOTNET_ROOT = "/home/jordan/.dotnet"
vim.env.PATH = "/home/jordan/.dotnet:/home/jordan/.dotnet/tools:" .. vim.env.PATH
vim.env.DOTNET_USE_POLLING_FILE_WATCHER = "1"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Add Mason bin to PATH (IMPORTANT: before loading plugins)
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH


require("vim-options")
require("lazy").setup("plugins")
require('luasnip.loaders.from_lua').load({paths = "~/.config/nvim/luasnippets/"})
