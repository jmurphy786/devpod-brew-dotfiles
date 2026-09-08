-- ============================================================
-- EDITOR OPTIONS
-- ============================================================

vim.g.mapleader = " "

-- Indentation
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- General
vim.opt.swapfile = false
vim.opt.autoread = true
vim.opt.autowriteall = false
vim.opt.ttimeoutlen = 10
vim.o.winborder = "rounded" -- hover / signature help / diagnostic floats
vim.opt.laststatus = 3 -- one statusline for the whole screen, not per-window

-- Built-in optional plugins (Nvim 0.12): :Undotree, :DiffTool
pcall(vim.cmd.packadd, "nvim.undotree")
pcall(vim.cmd.packadd, "nvim.difftool")

-- Persistent undo (browse it with :Undotree)
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("cache") .. "/undo"
vim.opt.undolevels = 10000
vim.opt.undoreload = 10000

-- Folding (treesitter-based)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99

-- Clipboard
vim.g.netrw_browsex_viewer = "explorer.exe"
if vim.fn.has("wsl") == 1 then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
end
vim.opt.clipboard = "unnamedplus"

-- ============================================================
-- DIAGNOSTICS
-- ============================================================

vim.diagnostic.config({
  signs = true,
  underline = true,
  virtual_text = true,
  update_in_insert = false,
})

-- ============================================================
-- AUTO COMMANDS
-- ============================================================

-- Force buffer check when regaining focus
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  command = "silent! checktime",
})

-- Auto-save (replaces auto-save.nvim)
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost", "BufLeave" }, {
  callback = function(args)
    local buf = args.buf
    if vim.bo[buf].modifiable
      and vim.bo[buf].buftype == ""
      and vim.api.nvim_buf_get_name(buf) ~= ""
      and vim.bo[buf].modified
    then
      vim.api.nvim_buf_call(buf, function() vim.cmd("silent! write") end)
    end
  end,
})

-- Prepopulate new note files
local templates = {
  ["*/meetings/*.md"] = { "## Attendees", "", "## Notes", "", "## Action Items", "", "## Tasks", "" },
  ["*/daily/*.md"] = { "## Notes", "", "## Tasks", "" },
}
for pattern, body in pairs(templates) do
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = pattern,
    callback = function(args)
      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
      if #lines == 0 or (#lines == 1 and lines[1] == "") then
        local header = { "# " .. vim.fn.expand("%:t:r"), "" }
        vim.list_extend(header, body)
        vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, header)
      end
    end,
  })
end

-- ============================================================
-- USER COMMANDS
-- ============================================================

-- :Jq [filter] - filter the current JSON buffer through jq (replaces jq.nvim)
vim.api.nvim_create_user_command("Jq", function(opts)
  local filter = opts.args ~= "" and opts.args or "."
  vim.cmd(string.format("%%!jq %s", vim.fn.shellescape(filter)))
end, { nargs = "?", desc = "Filter buffer through jq" })

-- :Meeting - pick a meeting type and create/open its note
vim.api.nvim_create_user_command("Meeting", function()
  vim.ui.select({ "Weekly Refinement", "1-1", "Daily Standup" }, { prompt = "Meeting type:" }, function(selected)
    if not selected then return end

    local date = os.date("%Y-%m-%d")
    local filepath = vim.fn.expand("~/work-notes/meetings/") .. selected:gsub(" ", "-") .. "-" .. date .. ".md"

    if vim.fn.filereadable(filepath) == 0 then
      vim.fn.writefile({ "# " .. selected .. " - " .. date, "", "## Notes", "", "## Tasks", "" }, filepath)
    end

    vim.cmd.edit(filepath)
  end)
end, { nargs = 0 })

-- :Task <ID> - create/open a Jira task note, eg. :Task NGP-417
vim.api.nvim_create_user_command("Task", function(opts)
  local task_id = opts.args

  if not task_id:match("^[A-Z]+%-%d+$") then
    vim.notify("Invalid format - use PREFIX-NUMBER (e.g. TRT-111)", vim.log.levels.WARN)
    return
  end

  local url = "https://cirdan.atlassian.net/browse/" .. task_id
  local filepath = vim.fn.expand("~/work-notes/tasks/") .. task_id .. ".md"

  if vim.fn.filereadable(filepath) == 0 then
    vim.fn.writefile({
      "---",
      "id: " .. task_id,
      "url: " .. url,
      "tags: [" .. task_id .. "]",
      "---",
      "# " .. task_id,
      "",
      "[" .. task_id .. "](" .. url .. ")",
      "",
      "## To Dos",
      "",
      "## Developer Notes",
      "",
      "## Testing",
      "",
    }, filepath)
  end

  vim.cmd.edit(filepath)
end, { nargs = 1 })

-- ============================================================
-- KEYMAPS
-- ============================================================

local map = vim.keymap.set

-- Open URL under cursor in the Windows default browser
map("n", "gx", function()
  vim.fn.jobstart({ "cmd.exe", "/c", "start", "", vim.fn.expand("<cfile>") }, { detach = true })
end, { desc = "Open URL in browser" })

-- Undo history (built-in, replaces telescope-undo)
map("n", "<leader>u", "<cmd>Undotree<cr>", { desc = "Undo tree" })

-- Buffers / windows
map("n", "<leader>r", "<cmd>bufdo! edit!<cr>", { desc = "Force reload all buffers" })
map("n", "<leader>k", "<cmd>close<cr>", { desc = "Close current window" })
map("n", "<leader>ml", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>=", "<C-w>=", { desc = "Equalise window sizes" })
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease height" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase width" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease width" })

-- Diff helpers (3-way merge)
map("n", "<leader>1", "<cmd>diffget LOCAL<cr>", { desc = "Diff: take LOCAL" })
map("n", "<leader>2", "<cmd>diffget BASE<cr>", { desc = "Diff: take BASE" })
map("n", "<leader>3", "<cmd>diffget REMOTE<cr>", { desc = "Diff: take REMOTE" })

-- Folds
map("n", "<leader>ft", "za", { desc = "Fold toggle" })
map("n", "<leader>fT", "zA", { desc = "Fold toggle parent" })
map("n", "<leader>fc", "zM", { desc = "Fold close all" })
map("n", "<leader>fo", "zR", { desc = "Fold open all" })

-- Daily note
map("n", "<leader>dn", function()
  vim.cmd.edit(vim.fn.expand("~/work-notes/daily/") .. os.date("%Y-%m-%d") .. ".md")
end, { desc = "Open daily note" })

-- Text object: inside code fence (yic / dic / vic)
map({ "o", "x" }, "ic", function()
  local start_line = vim.fn.search("^```", "bnW")
  local end_line = vim.fn.search("^```", "nW")
  if start_line > 0 and end_line > 0 then
    vim.cmd("normal! " .. (start_line + 1) .. "GV" .. (end_line - 1) .. "G")
  end
end, { silent = true, desc = "Inside code fence" })

-- ============================================================
-- AI HELPERS
-- ============================================================

-- Copy file path (optionally with a line range and a note) for pasting into AI chats
local function copy_ref(opts)
  local ref = vim.fn.expand("%:.")

  if opts.visual then
    -- '< and '> are only set after leaving visual mode, so read the live selection
    local start_line, end_line = vim.fn.line("v"), vim.fn.line(".")
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    ref = ref .. ":" .. start_line .. ":" .. end_line
  end

  local note = vim.fn.input("Prompt (optional): ")
  if note ~= "" then
    ref = ref .. " " .. note
  end

  vim.fn.setreg("+", ref)
  vim.notify("Copied: " .. ref)
end

map("n", "<leader>cp", function() copy_ref({}) end, { desc = "Copy file path" })
map("v", "<leader>cp", function() copy_ref({ visual = true }) end, { desc = "Copy file path + range" })


-- ============================================================
-- PROJECT / DIRECTORY NAVIGATION
-- ============================================================

-- Change the working directory (and the nvim-tree root) together
local function set_root(dir)
  vim.cmd.lcd(vim.fn.fnameescape(dir))
  local ok, api = pcall(require, "nvim-tree.api")
  if ok then api.tree.change_root(dir) end
  vim.notify("  " .. vim.fn.fnamemodify(dir, ":~"))
end

map("n", "<leader>cd", function()
  local cwd = vim.fn.getcwd()
  local dirs = {}
  for name, type in vim.fs.dir(cwd) do
    if type == "directory" and not name:match("^%.") then
      table.insert(dirs, cwd .. "/" .. name)
    end
  end

  if #dirs == 0 then
    vim.notify("No subdirectories in: " .. vim.fn.fnamemodify(cwd, ":~"))
    return
  end

  vim.ui.select(dirs, {
    prompt = "Select directory (current: " .. vim.fn.fnamemodify(cwd, ":~") .. ")",
    format_item = function(item) return vim.fn.fnamemodify(item, ":t") end,
  }, function(choice)
    if choice then set_root(choice) end
  end)
end, { desc = "Change directory (down)" })

map("n", "<leader>cu", function()
  set_root(vim.fn.fnamemodify(vim.fn.getcwd(), ":h"))
end, { desc = "Change directory (up)" })

map("n", "<leader>cw", function()
  vim.notify("  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~"))
end, { desc = "Show current directory" })

map("n", "<leader>cr", function()
  local start_dir = vim.fn.getenv("PWD")
  if start_dir and start_dir ~= vim.NIL then set_root(start_dir) end
end, { desc = "Reset to initial directory" })
