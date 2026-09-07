-- ~/.config/nvim/lua/plugins/chainsaw.lua (or wherever you configure it)
-- Adds C# ("cs") log statements to nvim-chainsaw, alongside the built-in
-- JavaScript ones, so the log command "chains" the right console call
-- based on filetype automatically.

return {
	"chrisgrieser/nvim-chainsaw",
	event = "VeryLazy",
	keys = {
		{
			"<leader>lg",
			function() require("chainsaw").variableLog() end,
			mode = { "n", "x" },
			desc = "Chainsaw: variable log",
		},
		-- optional extras, same pattern, different suffix key so they don't collide
		{
			"<leader>lo",
			function() require("chainsaw").objectLog() end,
			mode = { "n", "x" },
			desc = "Chainsaw: object log",
		},
		{
			"<leader>lm",
			function() require("chainsaw").messageLog() end,
			mode = "n",
			desc = "Chainsaw: message log",
		},
		{
			"<leader>lr",
			function() require("chainsaw").removeLogs() end,
			mode = "n",
			desc = "Chainsaw: remove all logs",
		},
	},
	opts = {
		logStatements = {

			-- log the name & value of the variable under the cursor
			variableLog = {
				javascript = 'console.log("{{marker}} {{var}}:", {{var}});',
				cs = 'Console.WriteLine("{{marker}} {{var}}: " + {{var}});',
			},

			-- inspect/dump an object's contents
			-- (requires `using System.Text.Json;` at the top of the file)
			objectLog = {
				javascript = 'console.log("{{marker}} {{var}}:", JSON.stringify({{var}}));',
				cs = 'Console.WriteLine("{{marker}} {{var}}: " + System.Text.Json.JsonSerializer.Serialize({{var}}));',
			},

			-- inspect the type of the variable under cursor
			typeLog = {
				javascript = 'console.log("{{marker}} typeof {{var}}:", typeof {{var}});',
				cs = 'Console.WriteLine("{{marker}} typeof {{var}}: " + {{var}}.GetType());',
			},

			-- assertion statement for the variable under cursor
			assertLog = {
				javascript = 'console.assert({{var}}, "{{marker}}");',
				-- Debug.Assert is stripped in Release builds; swap for
				-- `if (!({{var}})) throw new Exception("{{marker}}");`
				-- if you want it to always run.
				cs = 'System.Diagnostics.Debug.Assert({{var}}, "{{marker}}");',
			},

			-- minimal control-flow marker log (no variable)
			emojiLog = {
				javascript = 'console.log("{{marker}}");',
				cs = 'Console.WriteLine("{{marker}}");',
			},

			-- create log statement, cursor positioned to type a custom message
			messageLog = {
				javascript = 'console.log("{{marker}} ");',
				cs = 'Console.WriteLine("{{marker}} ");',
			},

			-- prints the stacktrace of the current call
			stacktraceLog = {
				javascript = 'console.trace("{{marker}}");',
				cs = 'Console.WriteLine("{{marker}} " + System.Environment.StackTrace);',
			},

			-- debug/breakpoint statement
			debugLog = {
				javascript = "debugger;",
				-- requires the process to be run under a debugger to break
				cs = "System.Diagnostics.Debugger.Break();",
			},

			-- clearing statement
			clearLog = {
				javascript = "console.clear();",
				cs = "Console.Clear();",
			},

			-- NOTE: timeLog needs a start AND an end template (1st call starts
			-- timing, 2nd call logs the duration). Check log-statements-data.lua
			-- for the exact key names chainsaw expects here (may not simply be
			-- a flat string like the others) before relying on this block.
			-- timeLog = {
			-- 	cs = { ... },
			-- },
		},
	},
}
