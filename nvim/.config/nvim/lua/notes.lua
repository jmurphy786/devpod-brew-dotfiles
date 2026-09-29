local util = require("notes.util")
local tags = require("notes.tags")

local root = util.root
local sanitize_title = util.sanitize_title
local load_template = util.load_template

local function create_note(root, dir, title, template)
  vim.fn.mkdir(root .. "/" .. dir, "p")
  local path = root .. "/" .. dir .. "/" .. title .. ".md"
  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile(load_template(root, template, { title = title }), path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function resolve_note(root, title)
  for _, candidate in ipairs({ root .. "/" .. title .. ".md", root .. "/" .. title }) do
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  local stem = title:match("([^/]+)$") or title
  local found = vim.fs.find(stem .. ".md", { path = root, limit = 1, type = "file" })
  if found[1] then
    return found[1]
  end
end

local function extract_wikilink()
  local line = vim.fn.getline(".")
  local col = vim.fn.col(".") - 1
  local init = 1
  while true do
    local start = line:find("[[", init, true)
    if not start then
      return
    end
    local stop = line:find("]]", start + 2, true)
    if not stop then
      return
    end
    if col >= start - 1 and col <= stop + 1 then
      local content = line:sub(start + 2, stop - 1)
      return sanitize_title(content:match("^([^|#]*)"))
    end
    init = stop + 2
  end
end

local function follow_or_create()
  local title = extract_wikilink()
  if not title then
    local tag = tags.at_cursor()
    if tag then
      local existed = tags.exists(root, tag)
      vim.cmd.edit(vim.fn.fnameescape(tags.create(root, tag)))
      if not existed then
        vim.notify("Created tag " .. tag)
      end
      return
    end
  end
  if not title or title == "" then
    vim.notify("No [[wikilink]] or tag under cursor")
    return
  end
  local path = resolve_note(root, title)
  if path then
    vim.cmd.edit(vim.fn.fnameescape(path))
  else
    create_note(root, "0-inbox", title, "inbox")
    vim.notify("Created 0-inbox/" .. title .. ".md")
  end
end

local function add_tags(new_tags)
  if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("Current buffer is not a note file")
    return
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local fm_end = tags.frontmatter_end(lines)

  local tags_start, tags_stop, items = nil, nil, {}
  if fm_end > 0 then
    for i = 2, fm_end - 1 do
      local value = lines[i]:match("^%s*tags:%s*(.-)%s*$")
      if value then
        tags_start = i
        tags_stop = i
        if value:match("^%[") then
          items = tags.parse_tag_list(value:match("%[(.-)%]"))
        elseif value == "" then
          for j = i + 1, fm_end - 1 do
            if lines[j]:match("^%s*-") then
              tags_stop = j
            else
              break
            end
          end
          for j = i + 1, tags_stop do
            local item = lines[j]:match("^%s*-%s*(.-)%s*$")
            if item then
              table.insert(items, item)
            end
          end
        else
          items = { value:gsub('["%[%]]', "") }
        end
        break
      end
    end
  end

  local seen, merged = {}, {}
  local function push(tag)
    if tag ~= "" and not seen[tag] then
      seen[tag] = true
      table.insert(merged, tag)
    end
  end
  for _, tag in ipairs(items) do
    push(tag)
  end
  for _, tag in ipairs(new_tags) do
    push(tag)
  end

  local inline = "tags: [" .. table.concat(merged, ", ") .. "]"
  local new_lines = {}
  if tags_start then
    for i, l in ipairs(lines) do
      if i == tags_start then
        table.insert(new_lines, inline)
      elseif i > tags_start and i <= tags_stop then
      else
        table.insert(new_lines, l)
      end
    end
  elseif fm_end > 0 then
    for i, l in ipairs(lines) do
      table.insert(new_lines, l)
      if i == fm_end - 1 then
        table.insert(new_lines, inline)
      end
    end
  else
    new_lines = { "---", inline, "---", "" }
    vim.list_extend(new_lines, lines)
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, new_lines)
  vim.cmd("silent! write")
  vim.notify("Tags: " .. table.concat(merged, ", "))
end

-- Lists notes carrying the tag inline (#tag) or in frontmatter (tags: [..] or YAML list).
local function find_tagged(tag)
  local t = vim.fn.escape(tag, "\\.^$*+?()[]{}|")
  require("telescope.builtin").find_files({
    prompt_title = "#" .. tag,
    cwd = root,
    find_command = {
      "rg",
      "-l",
      "--glob",
      "*.md",
      "-e",
      "(^|\\s)#" .. t .. "([\\s.,;:!?)]|$)",
      "-e",
      "^tags:.*[\\[,\\s]" .. t .. "\\s*[,\\]]",
      "-e",
      "^\\s*-\\s*" .. t .. "\\s*$",
    },
  })
end

local function pick_tag(callback)
  local counts = tags.usage(root)
  local names = vim.list_extend({}, (tags.registry(root)))
  if #names == 0 then
    vim.notify("No tags registered - create one with :TagNew or <leader>zf")
    return
  end
  table.sort(names, function(a, b)
    local ca, cb = counts[a] or 0, counts[b] or 0
    if ca == cb then
      return a < b
    end
    return ca > cb
  end)
  vim.ui.select(names, {
    prompt = "Tags:",
    format_item = function(tag)
      return tag .. " (" .. (counts[tag] or 0) .. ")"
    end,
  }, function(choice)
    if choice then
      callback(choice)
    end
  end)
end

local function new_note_command(dir, template, prompt)
  return function(opts)
    local function make(title)
      create_note(root, dir, title, template)
    end
    local title = sanitize_title(opts.args or "")
    if title ~= "" then
      make(title)
    else
      vim.ui.input({ prompt = prompt }, function(input)
        local t = sanitize_title(input or "")
        if t ~= "" then
          make(t)
        end
      end)
    end
  end
end

vim.api.nvim_create_user_command("Zettel", new_note_command("00-zettelkasten", "zettel", "Zettel title: "), {
  nargs = "?",
  desc = "New zettel in 00-zettelkasten (verbose title)",
})
vim.api.nvim_create_user_command("Inbox", new_note_command("0-inbox", "inbox", "Inbox note title: "), {
  nargs = "?",
  desc = "Quick capture note in 0-inbox",
})

local function complete_tags(lead)
  local prefix = lead:gsub("^#", "")
  return vim.tbl_filter(function(t)
    return t:find(prefix, 1, true) == 1
  end, (tags.registry(root)))
end

vim.api.nvim_create_user_command("Tag", function(opts)
  local new_tags = {}
  for tag in opts.args:gmatch("[^%s]+") do
    tag = tag:gsub("^#", "")
    if not tags.exists(root, tag) then
      vim.notify("Unknown tag '" .. tag .. "' - create it with :TagNew " .. tag, vim.log.levels.WARN)
      return
    end
    table.insert(new_tags, tag)
  end
  add_tags(new_tags)
end, { nargs = "+", complete = complete_tags, desc = "Add registered tags to the current note's frontmatter" })

vim.api.nvim_create_user_command("TagNew", function(opts)
  local tag = opts.args:gsub("^#", "")
  if not tags.valid(tag) then
    vim.notify("Invalid tag name: " .. tag .. " (letters, digits, _ - /)", vim.log.levels.WARN)
    return
  end
  if tags.exists(root, tag) then
    vim.notify("Tag " .. tag .. " already exists")
  else
    tags.create(root, tag)
    vim.notify("Created tag " .. tag)
  end
end, { nargs = 1, complete = complete_tags, desc = "Register a new tag (creates tags/<tag>.md)" })

vim.api.nvim_create_user_command("Tags", function(opts)
  if opts.args == "" then
    pick_tag(find_tagged)
    return
  end
  find_tagged((opts.args:gsub("^#", "")))
end, {
  nargs = "?",
  complete = complete_tags,
  desc = "List notes carrying a tag (picker if no tag given)",
})

local NEW_MEETING_TYPE = "+ New meeting type..."
local ADHOC_MEETING = "Ad-hoc meeting..."

local function meeting_types()
  local types = {}
  for _, file in ipairs(vim.fn.globpath(root .. "/templates/meetings", "*.md", false, true)) do
    table.insert(types, vim.fn.fnamemodify(file, ":t:r"))
  end
  table.sort(types)
  return types
end

-- Opens (or creates) meetings/<Name>-<date>.md; template is relative to templates/.
local function open_meeting(name, template)
  local date = os.date("%Y-%m-%d")
  local slug = name:gsub(" ", "-")
  vim.fn.mkdir(root .. "/meetings", "p")
  local filepath = root .. "/meetings/" .. slug .. "-" .. date .. ".md"
  if vim.fn.filereadable(filepath) == 0 then
    vim.fn.writefile(load_template(root, template, { title = name .. " - " .. date }), filepath)
  end
  vim.cmd.edit(vim.fn.fnameescape(filepath))
end

local function prompt_title(prompt, callback)
  vim.ui.input({ prompt = prompt }, function(input)
    local title = sanitize_title(input or "")
    if title ~= "" then
      callback(title)
    end
  end)
end

local function new_meeting_type()
  prompt_title("New meeting type name: ", function(name)
    local dir = root .. "/templates/meetings"
    vim.fn.mkdir(dir, "p")
    local path = dir .. "/" .. name .. ".md"
    if vim.fn.filereadable(path) == 0 then
      local base = root .. "/templates/meeting.md"
      local lines = vim.fn.filereadable(base) == 1 and vim.fn.readfile(base)
        or { "# {{title}}", "", "## Notes", "", "## Tasks", "" }
      vim.fn.writefile(lines, path)
    end
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.notify("Edit the template for '" .. name .. "' - it now appears in :Meeting")
  end)
end

local function handle_meeting_choice(choice)
  if not choice then
    return
  elseif choice == NEW_MEETING_TYPE then
    new_meeting_type()
  elseif choice == ADHOC_MEETING then
    prompt_title("Meeting title: ", function(title)
      open_meeting(title, "meeting")
    end)
  else
    open_meeting(choice, "meetings/" .. choice)
  end
end

vim.api.nvim_create_user_command("Meeting", function(opts)
  if opts.args ~= "" then
    handle_meeting_choice(opts.args)
    return
  end
  local items = meeting_types()
  table.insert(items, NEW_MEETING_TYPE)
  table.insert(items, ADHOC_MEETING)
  vim.ui.select(items, { prompt = "Meeting type:" }, handle_meeting_choice)
end, {
  nargs = "?",
  complete = function(lead)
    return vim.tbl_filter(function(t)
      return t:lower():find(lead:lower(), 1, true) == 1
    end, meeting_types())
  end,
  desc = "Open/create today's meeting note",
})

vim.api.nvim_create_user_command("Task", function(opts)
  local task_id = opts.args
  if not task_id:match("^[A-Z]+%-%d+$") then
    vim.notify("Invalid format - use PREFIX-NUMBER (e.g. TRT-111)", vim.log.levels.WARN)
    return
  end
  local url = "https://cirdan.atlassian.net/browse/" .. task_id
  local filepath = root .. "/tasks/" .. task_id .. ".md"
  if vim.fn.filereadable(filepath) == 0 then
    vim.fn.mkdir(root .. "/tasks", "p")
    vim.fn.writefile({
      "---",
      "id: " .. task_id,
      "url: " .. url,
      "tags: [task]",
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
  vim.cmd.edit(vim.fn.fnameescape(filepath))
end, { nargs = 1, desc = "Open/create a Jira task note" })

-- Opens a note in a large centred float; q / <Esc> close it, edits save to the note.
local function peek(path)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor((vim.o.lines - vim.o.cmdheight) * 0.8)
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(scratch, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " " .. vim.fn.fnamemodify(path, ":t:r") .. " ",
    title_pos = "center",
  })
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
  end
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, close, { buffer = buf, nowait = true, desc = "Close note preview" })
  end
  -- The note buffer outlives the float, so drop the close maps with it.
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      for _, lhs in ipairs({ "q", "<Esc>" }) do
        pcall(vim.keymap.del, "n", lhs, { buffer = buf })
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then
        return true
      end
      if vim.api.nvim_get_current_win() == win then
        vim.schedule(close)
        return true
      end
    end,
  })
end

local function preview()
  local title = extract_wikilink()
  if title and title ~= "" then
    local path = resolve_note(root, title)
    if path then
      peek(path)
    else
      vim.notify("[[" .. title .. "]] does not exist yet - <leader>zf to create it")
    end
    return
  end
  local tag = tags.at_cursor()
  if tag then
    if tags.exists(root, tag) then
      peek(tags.path(root, tag))
    else
      vim.notify("Unknown tag " .. tag .. " - <leader>zf to create it")
    end
    return
  end
  vim.lsp.buf.hover({
    max_width = math.floor(vim.o.columns * 0.8),
    max_height = math.floor(vim.o.lines * 0.8),
  })
end

local tag_ns = vim.api.nvim_create_namespace("notes_tags")

local function check_tags(buf)
  local root = util.buf_vault(buf)
  if not root or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local _, known = tags.registry(root)
  local diagnostics = {}
  for _, hit in ipairs(tags.scan(vim.api.nvim_buf_get_lines(buf, 0, -1, false))) do
    if not known[hit.tag] then
      table.insert(diagnostics, {
        lnum = hit.lnum,
        col = hit.col,
        end_col = hit.end_col,
        severity = vim.diagnostic.severity.WARN,
        source = "notes",
        message = "Unknown tag " .. hit.tag .. " - <leader>zf to create it",
      })
    end
  end
  vim.diagnostic.set(tag_ns, buf, diagnostics)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    if not util.buf_vault(args.buf) then
      return
    end
    vim.keymap.set("n", "gf", function()
      if extract_wikilink() or tags.at_cursor() then
        vim.schedule(follow_or_create)
        return ""
      end
      return vim.keycode("gf")
    end, { buffer = args.buf, expr = true, desc = "Follow [[link]] / tag or create it" })
    vim.keymap.set("n", "K", preview, { buffer = args.buf, desc = "Preview [[link]] / tag, else hover" })
    vim.keymap.set("n", "<leader>.", preview, { buffer = args.buf, desc = "Preview [[link]] / tag, else hover" })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      buffer = args.buf,
      callback = function(ev)
        if ev.event ~= "InsertLeave" then
          tags.invalidate(util.buf_vault(ev.buf))
        end
        check_tags(ev.buf)
      end,
    })
    -- mini.pairs inserts "[]" through a mapping, which blink never sees as a
    -- trigger character, so open the tag menu after `[` / `,` on the tags line.
    vim.api.nvim_create_autocmd("TextChangedI", {
      buffer = args.buf,
      callback = function(ev)
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local before = vim.api.nvim_get_current_line():sub(1, col)
        if before:match("[%[,]%s*$") and require("notes.blink_tags").in_frontmatter_tags(ev.buf, row, before) then
          local ok, blink = pcall(require, "blink.cmp")
          if ok and not blink.is_menu_visible() then
            blink.show({ providers = { "notes_tags" } })
          end
        end
      end,
    })
    check_tags(args.buf)
  end,
})

local map = vim.keymap.set

map("n", "<leader>zn", "<cmd>Zettel<cr>", { desc = "Notes: new zettel" })
map("n", "<leader>zi", "<cmd>Inbox<cr>", { desc = "Notes: capture to 0-inbox" })
map("n", "<leader>zf", follow_or_create, { desc = "Notes: follow [[link]] / tag or create it" })

map("n", "<leader>zo", function()
  require("telescope.builtin").find_files({ cwd = root })
end, { desc = "Notes: find note in vault" })

map("n", "<leader>zt", function()
  pick_tag(find_tagged)
end, { desc = "Notes: pick tag, list tagged notes" })

map("n", "<leader>zb", function()
  local stem = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t:r")
  if stem == "" then
    vim.notify("Current buffer has no file")
    return
  end
  local builtin = require("telescope.builtin")
  if #vim.lsp.get_clients({ bufnr = 0, name = "markdown_oxide" }) > 0 then
    if pcall(builtin.lsp_references, { include_declaration = false }) then
      return
    end
  end
  builtin.live_grep({
    search = "[[" .. stem,
    cwd = root,
    additional_args = { "--fixed-strings" },
  })
end, { desc = "Notes: backlinks to current note" })

map("n", "<leader>zl", function()
  local stem = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t:r")
  if stem == "" then
    vim.notify("Current buffer has no file")
    return
  end
  local link = "[[" .. stem .. "]]"
  vim.fn.setreg("+", link)
  vim.fn.setreg('"', link)
  vim.notify("Copied " .. link)
end, { desc = "Notes: copy [[wikilink]] to this note" })

map("n", "<leader>zv", function()
  vim.cmd.lcd(vim.fn.fnameescape(root))
  local ok, api = pcall(require, "nvim-tree.api")
  if ok then
    api.tree.change_root(root)
  end
  vim.notify("Vault: " .. root)
end, { desc = "Notes: cd to vault" })

-- Daily notes folder from .moxide.toml (daily_notes_folder), default "daily".
local function daily_folder(root)
  local ok, lines = pcall(vim.fn.readfile, root .. "/.moxide.toml")
  for _, line in ipairs(ok and lines or {}) do
    local dir = line:match('^%s*daily_notes_folder%s*=%s*"(.-)"')
    if dir then
      return dir
    end
  end
  return "daily"
end

-- Most recent daily note (YYYY-MM-DD.md) dated before `date`.
local function previous_daily(dir, date)
  local best
  for name, type in vim.fs.dir(dir) do
    local d = type == "file" and name:match("^(%d%d%d%d%-%d%d%-%d%d)%.md$")
    if d and d < date and (not best or d > best) then
      best = d
    end
  end
  return best and (dir .. "/" .. best .. ".md")
end

-- Unchecked "- [ ]" tasks plus the lines nested under them, each block
-- dedented to its task's indent.
local function unfinished_tasks(path)
  local out, block_indent = {}, nil
  for _, line in ipairs(vim.fn.readfile(path)) do
    local indent = #line:match("^%s*")
    if block_indent and indent > block_indent and line:match("%S") then
      table.insert(out, line:sub(block_indent + 1))
    elseif line:match("^%s*[-*+] %[ %]") then
      block_indent = indent
      table.insert(out, line:sub(indent + 1))
    else
      block_indent = nil
    end
  end
  return out
end

-- Puts carried-over tasks under the "## Tasks" heading (added if missing).
local function insert_tasks(lines, tasks)
  for i, line in ipairs(lines) do
    if line:match("^##%s+Tasks%s*$") then
      local at = i + 1
      if lines[at] == "" then
        at = at + 1
      end
      for j, task in ipairs(tasks) do
        table.insert(lines, at + j - 1, task)
      end
      return lines
    end
  end
  vim.list_extend(lines, { "", "## Tasks", "" })
  vim.list_extend(lines, tasks)
  return lines
end

-- Opens today's daily note in the vault.
-- A new note inherits the unfinished tasks of the previous daily note.
-- Works without markdown-oxide, unlike :Daily.
local function open_daily()
  local date = os.date("%Y-%m-%d")
  local dir = root .. "/" .. daily_folder(root)
  local path = dir .. "/" .. date .. ".md"
  if vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(dir, "p")
    local lines = load_template(root, "daily", { title = date })
    local prev = previous_daily(dir, date)
    local tasks = prev and unfinished_tasks(prev) or {}
    if #tasks > 0 then
      lines = insert_tasks(lines, tasks)
      vim.notify(("Carried over %d line(s) of open tasks from %s"):format(#tasks, vim.fn.fnamemodify(prev, ":t:r")))
    end
    vim.fn.writefile(lines, path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

vim.api.nvim_create_user_command("DailyNote", open_daily, { desc = "Open/create today's daily note" })
-- User commands must start uppercase, so `:dn` is a command-line abbreviation
-- that only expands when it is the whole command.
vim.cmd([[cnoreabbrev <expr> dn getcmdtype() ==# ':' && getcmdline() ==# 'dn' ? 'DailyNote' : 'dn']])
map("n", "<leader>dn", open_daily, { desc = "Open daily note (current vault)" })

-- Notes for today: date in the filename, frontmatter `date:` of today, or
-- created (birth time) today.
local function todays_notes(root)
  local today = os.date("%Y-%m-%d")
  local midnight = os.time({ year = os.date("%Y"), month = os.date("%m"), day = os.date("%d"), hour = 0 })
  local found = {}
  for rel, type in vim.fs.dir(root, {
    depth = 10,
    skip = function(dir)
      return not (dir:match("^%.") or dir == "templates")
    end,
  }) do
    if type == "file" and rel:match("%.md$") then
      local path = root .. "/" .. rel
      local hit = rel:find(today, 1, true) ~= nil
      if not hit then
        local stat = vim.uv.fs_stat(path)
        hit = stat and stat.birthtime.sec > 0 and stat.birthtime.sec >= midnight
      end
      if not hit then
        local ok, head = pcall(vim.fn.readfile, path, "", 10)
        for _, line in ipairs(ok and head or {}) do
          if line:match("^date:%s*" .. today) then
            hit = true
            break
          end
        end
      end
      if hit then
        table.insert(found, rel)
      end
    end
  end
  table.sort(found)
  return found
end

vim.api.nvim_create_user_command("Today", function()
  local files = todays_notes(root)
  if #files == 0 then
    vim.notify("Nothing for today in the vault")
    return
  end
  local conf = require("telescope.config").values
  require("telescope.pickers")
    .new({}, {
      prompt_title = "Today",
      cwd = root,
      finder = require("telescope.finders").new_table({
        results = files,
        entry_maker = require("telescope.make_entry").gen_from_file({ cwd = root }),
      }),
      previewer = conf.file_previewer({}),
      sorter = conf.file_sorter({}),
    })
    :find()
end, { desc = "Notes for today: dated today, created today, or date: today" })
