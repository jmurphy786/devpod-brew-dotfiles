-- ============================================================
-- EDITOR OPTIONS
-- ============================================================

-- Indentation
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")

-- Line numbers
vim.opt.relativenumber = true
vim.opt.number = true

-- General
vim.g.mapleader = " "
vim.opt.swapfile = false
vim.opt.clipboard = "unnamedplus"
vim.opt.autoread = true
vim.opt.autowriteall = false
vim.opt.lazyredraw = false
vim.opt.ttimeoutlen = 10  -- default is often too high
-- Folding (treesitter-based)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 99


-- ============================================================
-- CLIPBOARD (WSL Windows)
-- ============================================================

if vim.fn.has("wsl") == 1 and vim.fn.executable("clip.exe") == 1 then
  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      ["*"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    },
    cache_enabled = 0,
  }
else
  vim.g.clipboard = {
    name = "OSC52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = function() return {} end,
      ["*"] = function() return {} end,
    },
  }
end

vim.opt.clipboard = "unnamedplus"

vim.g.netrw_browsex_viewer = "explorer.exe"


-- ============================================================
-- APPEARANCE
-- ============================================================

-- Transparent backgrounds
vim.api.nvim_set_hl(0, "Normal",        { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalFloat",   { bg = "NONE" })
vim.api.nvim_set_hl(0, "LineNr",        { bg = "NONE" })
vim.api.nvim_set_hl(0, "SignColumn",    { bg = "NONE" })
vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE" })

vim.cmd([[highlight clear SignColumn]])
vim.cmd([[highlight clear LineNr]])
vim.cmd([[highlight clear CursorLineNr]])

-- Diagnostic line highlights
vim.cmd([[highlight DiagnosticLineError guibg=#3f1f1f gui=NONE]])
vim.cmd([[highlight DiagnosticLineWarn  guibg=#3f3f1f gui=NONE]])

-- Neo-tree filename colours
vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function()
    vim.api.nvim_set_hl(0, "NeoTreeFileName",       { fg = "#dde1e6" })
    vim.api.nvim_set_hl(0, "NeoTreeFileNameOpened", { fg = "#ffffff" })
  end,
})


-- ============================================================
-- DIAGNOSTICS
-- ============================================================

vim.diagnostic.config({
  signs = true,
  underline = true,
  virtual_text = true,
  update_in_insert = false,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  callback = function()
    vim.diagnostic.show()
  end,
})

-- reload all buffers
vim.opt.autoread = true
vim.opt.autowriteall = false  -- Don't auto-save

-- ============================================================
-- AUTO COMMANDS
-- ============================================================

-- Force buffer check when regaining focus
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  command = "silent! checktime",
})

-- Prepopulate new meeting files
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*/meetings/*.md",
  callback = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local is_empty = #lines == 0 or (#lines == 1 and lines[1] == "")
    if is_empty then
      local name = vim.fn.expand("%:t:r")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "# " .. name,
        "",
        "## Attendees",
        "",
        "## Notes",
        "",
        "## Action Items",
        "",
        "## Tasks",
        "",
      })
    end
  end,
})

-- Prepopulate new daily note files
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*/daily/*.md",
  callback = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local is_empty = #lines == 0 or (#lines == 1 and lines[1] == "")
    if is_empty then
      local date = vim.fn.expand("%:t:r")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "# " .. date,
        "",
        "## Notes",
        "",
        "## Tasks",
        "",
      })
    end
  end,
})


-- ============================================================
-- USER COMMANDS
-- ============================================================

-- :Meeting - pick a meeting type and create/open its note
vim.api.nvim_create_user_command("Meeting", function()
  local meeting_types = { "Weekly Refinement", "1-1", "Daily Standup" }

  vim.ui.select(meeting_types, { prompt = "Meeting type:" }, function(selected)
    if not selected then return end

    local date     = os.date("%Y-%m-%d")
    local filename = selected:gsub(" ", "-") .. "-" .. date .. ".md"
    local filepath = vim.fn.expand("~/work-notes/meetings/") .. filename

    if vim.fn.filereadable(filepath) == 0 then
      vim.fn.writefile({
        "# " .. selected .. " - " .. date,
        "",
        "## Notes",
        "",
        "## Tasks",
        "",
      }, filepath)
    end

    vim.cmd("edit " .. filepath)
  end)
end, { nargs = 0 })

-- :Task <ID> - create/open a Jira task note eg. :Task NGP-417
vim.api.nvim_create_user_command("Task", function(opts)
  local task_id = opts.args

  if task_id == "" then
    vim.notify("Usage: :Task TRT-111", vim.log.levels.WARN)
    return
  end

  if not task_id:match("^[A-Z]+%-%d+$") then
    vim.notify("Invalid format - use PREFIX-NUMBER (e.g. TRT-111)", vim.log.levels.WARN)
    return
  end

  local url      = "https://cirdan.atlassian.net/browse/" .. task_id
  local filepath = vim.fn.expand("~/work-notes/tasks/") .. task_id .. ".md"

  if vim.fn.filereadable(filepath) == 0 then
    vim.fn.writefile({
      "---",
      "id: "   .. task_id,
      "url: "  .. url,
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

  vim.cmd("edit " .. filepath)
end, { nargs = 1 })


-- ============================================================
-- KEYMAPS
-- ============================================================

-- Open URL under cursor in Windows default browser
vim.keymap.set("n", "gx", function()
  local url = vim.fn.expand("<cfile>")
  vim.fn.jobstart({ "cmd.exe", "/c", "start", "", url }, { detach = true })
end, { desc = "Open URL in browser" })

-- Daily note
vim.keymap.set("n", "<leader>dn", function()
  local date = os.date("%Y-%m-%d")
  local path  = vim.fn.expand("~/work-notes/daily/") .. date .. ".md"
  vim.cmd("edit " .. path)
end, { desc = "Open daily note" })

-- Paste image from clipboard
vim.keymap.set("n", "<leader>mp", function()
  local img_dir = vim.fn.expand("%:p:h") .. "/images"
  vim.fn.mkdir(img_dir, "p")

  local tmp_win = "C:\\Users\\jordan.murphy\\AppData\\Local\\Temp\\nvim_paste.png"
  local ps_cmd  = string.format(
    'powershell.exe -c "Add-Type -AssemblyName System.Windows.Forms; \\$img = [System.Windows.Forms.Clipboard]::GetImage(); if (\\$img) { \\$img.Save(\'%s\') }"',
    tmp_win
  )

  vim.fn.system(ps_cmd)
  vim.fn.system("sleep 1")

  vim.ui.input({ prompt = "Image name: " }, function(name)
    local filename = (name and name ~= "") and (name .. ".png") or (os.date("%Y-%m-%d_%H-%M-%S") .. ".png")
    local filepath  = img_dir .. "/" .. filename
    local tmp_wsl   = vim.fn.system("wslpath -u '" .. tmp_win:gsub("\\", "\\\\") .. "'"):gsub("\n", "")

    vim.fn.system("cp " .. tmp_wsl .. " " .. filepath)

    if vim.fn.filereadable(filepath) == 1 then
      local rel_path = "images/" .. filename
      vim.api.nvim_put({ "![](" .. rel_path .. ")" }, "c", true, true)
      vim.notify("Image saved: " .. rel_path)
    else
      vim.notify("No image in clipboard or save failed", vim.log.levels.ERROR)
    end
  end)
end, { desc = "Paste image from clipboard" })

-- Force reload all buffers
vim.keymap.set("n", "<leader>r", function()
  vim.cmd("bufdo! edit!")
  print("All buffers force reloaded")
end, { desc = "Force reload all buffers" })

-- Close current window
vim.keymap.set("n", "<leader>k", "<cmd>close<CR>", { desc = "Close current window" })

-- Window splits & navigation
vim.keymap.set("n", "<leader>ml", "<cmd>vsplit<cr>",                          { desc = "Vertical split" })
vim.keymap.set("n", "<C-h>",      "<C-w>h",                                   { desc = "Move to left window" })
vim.keymap.set("n", "<C-j>",      "<C-w>j",                                   { desc = "Move to window below" })
vim.keymap.set("n", "<C-k>",      "<C-w>k",                                   { desc = "Move to window above" })
vim.keymap.set("n", "<C-l>",      "<C-w>l",                                   { desc = "Move to right window" })
vim.keymap.set("n", "<leader>=",  "<C-w>=",                                   { desc = "Equalise window sizes" })

-- Window resizing
vim.keymap.set("n", "<C-Up>",    ":resize +2<CR>",          { desc = "Increase height" })
vim.keymap.set("n", "<C-Down>",  ":resize -2<CR>",          { desc = "Decrease height" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase width" })
vim.keymap.set("n", "<C-Left>",  ":vertical resize -2<CR>", { desc = "Decrease width" })

-- Diff helpers
vim.keymap.set("n", "<leader>1", ":diffget LOCAL<CR>",  { desc = "Diff: take LOCAL" })
vim.keymap.set("n", "<leader>2", ":diffget BASE<CR>",   { desc = "Diff: take BASE" })
vim.keymap.set("n", "<leader>3", ":diffget REMOTE<CR>", { desc = "Diff: take REMOTE" })

-- Markdown heading navigation
vim.keymap.set("n", "]h", function() vim.fn.search("^#\\s") end,        { desc = "Next heading" })
vim.keymap.set("n", "[h", function() vim.fn.search("^#\\s", "b") end,   { desc = "Previous heading" })

-- Fold controls
vim.keymap.set("n", "<leader>ft", "za", { desc = "Fold toggle" })
vim.keymap.set("n", "<leader>fT", "zA", { desc = "Fold toggle parent" })
vim.keymap.set("n", "<leader>fc", "zM", { desc = "Fold close all" })
vim.keymap.set("n", "<leader>fo", "zR", { desc = "Fold open all" })

-- Diagnostics navigation
vim.keymap.set("n", "]d", function()
  require("trouble").next({ skip_groups = true, jump = true })
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[d", function()
  require("trouble").prev({ skip_groups = true, jump = true })
end, { desc = "Previous diagnostic" })

-- Telescope
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers sort_mru=true<cr>", { desc = "Find buffers (MRU)" })
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>",            { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",             { desc = "Live grep" })
vim.keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>",              { desc = "Recent files" })
vim.keymap.set("n", "<leader>sk", "<cmd>Telescope keymaps<CR>",               { desc = "Search keymaps" })

-- Text object: inside code fence (yic / dic / vic)
vim.keymap.set({ "o", "x" }, "ic", function()
  local start_line = vim.fn.search("^```", "bnW")
  local end_line   = vim.fn.search("^```", "nW")
  if start_line > 0 and end_line > 0 then
    vim.cmd("normal! " .. (start_line + 1) .. "GV" .. (end_line - 1) .. "G")
  end
end, { silent = true, desc = "Inside code fence" })


-- ============================================================
-- TELESCOPE: PROJECT PICKER
-- ============================================================

-- <leader>fp - browse Github projects then pick a file within them
vim.keymap.set("n", "<leader>fp", function()
  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf         = require("telescope.config").values
  local scan         = require("plenary.scandir")

  local base_path = vim.fn.expand("~/Documents/Github")
  local dirs      = scan.scan_dir(base_path, { only_dirs = true, depth = 1 })

  local projects = {}
  for _, dir in ipairs(dirs) do
    table.insert(projects, { name = dir:match("([^/]+)$"), path = dir })
  end

  pickers.new({}, {
    prompt_title = "Select Project",
    finder = finders.new_table({
      results     = projects,
      entry_maker = function(entry)
        return { value = entry.path, display = entry.name, ordinal = entry.name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local project = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        require("telescope.builtin").find_files({
          prompt_title = project.display,
          cwd          = project.value,
          attach_mappings = function(file_bufnr)
            actions.select_default:replace(function()
              local file = action_state.get_selected_entry()
              actions.close(file_bufnr)

              -- Open in the first non-floating window
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_config(win).relative == "" then
                  vim.api.nvim_set_current_win(win)
                  break
                end
              end

              vim.cmd("edit " .. vim.fn.fnameescape(file.value))
            end)
            return true
          end,
        })
      end)
      return true
    end,
  }):find()
end, { desc = "Pick project + file" })


-- ============================================================
-- DIRECTORY NAVIGATION
-- ============================================================

-- <leader>cd - change into a subdirectory
vim.keymap.set("n", "<leader>cd", function()
  local cwd  = vim.fn.getcwd()
  local dirs = vim.fn.systemlist('find "' .. cwd .. '" -mindepth 1 -maxdepth 1 -type d ! -name ".*" 2>/dev/null')

  if #dirs == 0 then
    print("No subdirectories found in: " .. vim.fn.fnamemodify(cwd, ":~"))
    return
  end

  vim.ui.select(dirs, {
    prompt      = "Select directory (current: " .. vim.fn.fnamemodify(cwd, ":~") .. ")",
    format_item = function(item) return vim.fn.fnamemodify(item, ":t") end,
  }, function(choice)
    if not choice then return end
    vim.cmd("lcd " .. vim.fn.fnameescape(choice))
    require("nvim-tree.api").tree.change_root(choice)
    print("  " .. vim.fn.fnamemodify(choice, ":~"))
  end)
end, { desc = "Change directory (down)" })

-- <leader>cu - go up to parent directory
vim.keymap.set("n", "<leader>cu", function()
  local parent = vim.fn.fnamemodify(vim.fn.getcwd(), ":h")
  vim.cmd("lcd ..")
  require("nvim-tree.api").tree.change_root(parent)
  print("  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~"))
end, { desc = "Change directory (up)" })

-- <leader>cw - show current working directory
vim.keymap.set("n", "<leader>cw", function()
  print("  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~"))
end, { desc = "Show current directory" })

-- <leader>cr - reset to directory nvim was opened from
vim.keymap.set("n", "<leader>cr", function()
  local start_dir = vim.fn.getenv("PWD")
  if start_dir and start_dir ~= vim.NIL then
    vim.cmd("lcd " .. vim.fn.fnameescape(start_dir))
    require("nvim-tree.api").tree.change_root(start_dir)
    print("  Reset to: " .. vim.fn.fnamemodify(start_dir, ":~"))
  end
end, { desc = "Reset to initial directory" })
