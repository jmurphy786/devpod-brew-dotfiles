local vaults = {
  work = "/mnt/c/users/jordan.murphy/Documents/work",
  personal = "/mnt/c/users/jordan.murphy/Documents/personal",
}

local function current_vault()
  local paths = {}
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" then
    table.insert(paths, vim.fs.normalize(bufname))
  end
  table.insert(paths, vim.fs.normalize(vim.fn.getcwd()))
  for _, p in ipairs(paths) do
    for name, root in pairs(vaults) do
      if p == root or p:sub(1, #root + 1) == root .. "/" then
        return name, root
      end
    end
  end
end

local function sanitize_title(title)
  title = title:gsub('[\\/:*?"<>|#%[%]]', " ")
  return title:gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function load_template(root, name, vars)
  vars = vim.tbl_extend("force", {
    title = "",
    date = os.date("%Y-%m-%d"),
    time = os.date("%H:%M"),
  }, vars or {})
  local lines = {}
  local file = io.open(root .. "/templates/" .. name .. ".md", "r")
  if file then
    for line in file:lines() do
      table.insert(lines, (line:gsub("{{%s*(%a+)%s*}}", function(k)
        return vars[k:lower()] or ("{{" .. k .. "}}")
      end)))
    end
    file:close()
  else
    lines = { "---", "tags: []", "---", "# " .. vars.title, "" }
  end
  return lines
end

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
  local name, root = current_vault()
  if not root then
    vim.notify("Not inside a notes vault")
    return
  end
  local title = extract_wikilink()
  if not title or title == "" then
    vim.notify("No [[wikilink]] under cursor")
    return
  end
  local path = resolve_note(root, title)
  if path then
    vim.cmd.edit(vim.fn.fnameescape(path))
  else
    create_note(root, "0-inbox", title, "inbox")
    vim.notify("Created 0-inbox/" .. title .. ".md (" .. name .. " vault)")
  end
end

local function parse_tag_list(value)
  local items = {}
  for item in (value or ""):gmatch("[^,]+") do
    item = item:gsub('["%[%]]', ""):match("^%s*(.-)%s*$")
    if item ~= "" then
      table.insert(items, item)
    end
  end
  return items
end

local function add_tags(new_tags)
  if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("Current buffer is not a note file")
    return
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local fm_end = 0
  if lines[1] == "---" then
    for i = 2, #lines do
      if lines[i] == "---" then
        fm_end = i
        break
      end
    end
  end

  local tags_start, tags_stop, items = nil, nil, {}
  if fm_end > 0 then
    for i = 2, fm_end - 1 do
      local value = lines[i]:match("^%s*tags:%s*(.-)%s*$")
      if value then
        tags_start = i
        tags_stop = i
        if value:match("^%[") then
          items = parse_tag_list(value:match("%[(.-)%]"))
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
    push(tag:gsub("^#", ""))
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

local function collect_tags(root)
  local counts = {}
  local result = vim.system({
    "rg",
    "-o",
    "--no-filename",
    "-e",
    "#[A-Za-z0-9][A-Za-z0-9/_-]*",
    "-e",
    "tags:.*",
    "-g",
    "*.md",
    root,
  }, { text = true }):wait()
  for line in (result.stdout or ""):gmatch("[^\r\n]+") do
    local items = {}
    if line:sub(1, 1) == "#" then
      items = { line:gsub("^#", "") }
    else
      local value = line:match("tags:%s*(.*)$")
      if value and value:match("%[") then
        items = parse_tag_list(value:match("%[(.-)%]"))
      end
    end
    for _, tag in ipairs(items) do
      if tag:match("^[A-Za-z0-9][A-Za-z0-9/_-]*$") then
        counts[tag] = (counts[tag] or 0) + 1
      end
    end
  end
  return counts
end

local function new_note_command(dir, template, prompt)
  return function(opts)
    local name, root = current_vault()
    if not root then
      vim.notify("Not inside a notes vault (use wn/pn)")
      return
    end
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

vim.api.nvim_create_user_command("Tag", function(opts)
  local tags = {}
  for tag in opts.args:gmatch("[^%s]+") do
    tag = tag:gsub("^#", "")
    if not tag:match("^[A-Za-z0-9][A-Za-z0-9/_-]*$") then
      vim.notify("Invalid tag name: " .. tag, vim.log.levels.WARN)
      return
    end
    table.insert(tags, tag)
  end
  add_tags(tags)
end, { nargs = "+", desc = "Add frontmatter tags to the current note" })

vim.api.nvim_create_user_command("Meeting", function()
  vim.ui.select({ "Weekly Refinement", "1-1", "Daily Standup" }, { prompt = "Meeting type:" }, function(selected)
    if not selected then
      return
    end
    local date = os.date("%Y-%m-%d")
    local filepath = vaults.work .. "/meetings/" .. selected:gsub(" ", "-") .. "-" .. date .. ".md"
    if vim.fn.filereadable(filepath) == 0 then
      vim.fn.writefile({ "# " .. selected .. " - " .. date, "", "## Notes", "", "## Tasks", "" }, filepath)
    end
    vim.cmd.edit(vim.fn.fnameescape(filepath))
  end)
end, { nargs = 0, desc = "Open/create today's meeting note (work vault)" })

vim.api.nvim_create_user_command("Task", function(opts)
  local task_id = opts.args
  if not task_id:match("^[A-Z]+%-%d+$") then
    vim.notify("Invalid format - use PREFIX-NUMBER (e.g. TRT-111)", vim.log.levels.WARN)
    return
  end
  local url = "https://cirdan.atlassian.net/browse/" .. task_id
  local filepath = vaults.work .. "/tasks/" .. task_id .. ".md"
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
end, { nargs = 1, desc = "Open/create a Jira task note (work vault)" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(args.buf))
    if bufname == "" or bufname == "." then
      return
    end
    local in_vault = false
    for _, root in pairs(vaults) do
      if bufname:sub(1, #root + 1) == root .. "/" then
        in_vault = true
        break
      end
    end
    if not in_vault then
      return
    end
    vim.keymap.set("n", "gf", function()
      if extract_wikilink() then
        follow_or_create()
        return ""
      end
      return vim.keycode("gf")
    end, { buffer = args.buf, expr = true, desc = "Follow [[link]] or create note" })
  end,
})

local map = vim.keymap.set

map("n", "<leader>zn", "<cmd>Zettel<cr>", { desc = "Notes: new zettel" })
map("n", "<leader>zi", "<cmd>Inbox<cr>", { desc = "Notes: capture to 0-inbox" })
map("n", "<leader>zf", follow_or_create, { desc = "Notes: follow [[link]] or create note" })

map("n", "<leader>zo", function()
  local _, root = current_vault()
  if not root then
    vim.notify("Not inside a notes vault")
    return
  end
  require("telescope.builtin").find_files({ cwd = root })
end, { desc = "Notes: find note in vault" })

map("n", "<leader>zt", function()
  local name, root = current_vault()
  if not root then
    vim.notify("Not inside a notes vault")
    return
  end
  local counts = collect_tags(root)
  local names = vim.tbl_keys(counts)
  if #names == 0 then
    vim.notify("No tags found in this vault")
    return
  end
  table.sort(names, function(a, b)
    if counts[a] == counts[b] then
      return a < b
    end
    return counts[a] > counts[b]
  end)
  vim.ui.select(names, {
    prompt = "Tags (" .. name .. "):",
    format_item = function(tag)
      return tag .. " (" .. counts[tag] .. ")"
    end,
  }, function(choice)
    if not choice then
      return
    end
    require("telescope.builtin").live_grep({ search = choice, cwd = root })
  end)
end, { desc = "Notes: pick tag, grep occurrences" })

map("n", "<leader>zb", function()
  local _, root = current_vault()
  local stem = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t:r")
  if not root or stem == "" then
    vim.notify("Not inside a notes vault")
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
  local names = vim.tbl_keys(vaults)
  table.sort(names)
  vim.ui.select(names, { prompt = "Switch to vault:" }, function(choice)
    if not choice then
      return
    end
    vim.cmd.lcd(vim.fn.fnameescape(vaults[choice]))
    local ok, api = pcall(require, "nvim-tree.api")
    if ok then
      api.tree.change_root(vaults[choice])
    end
    vim.notify("Vault: " .. choice .. " (" .. vaults[choice] .. ")")
  end)
end, { desc = "Notes: switch vault" })

map("n", "<leader>dn", function()
  if not pcall(vim.cmd, "Daily Today") then
    vim.notify("No markdown-oxide client - open a markdown note first", vim.log.levels.WARN)
  end
end, { desc = "Open daily note (current vault)" })
