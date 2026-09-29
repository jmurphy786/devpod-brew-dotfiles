-- Tag registry: a tag exists when <vault>/tags/<tag>.md exists (nested tags
-- like project/ptl live in subfolders). Completion, :Tag and the unknown-tag
-- diagnostics all read from here so near-duplicate tags can't creep in.
local util = require("notes.util")

local M = {}

M.dir = "tags"

local cache = {}

function M.valid(tag)
  return tag:match("^[A-Za-z0-9][A-Za-z0-9/_-]*$") ~= nil
end

function M.path(root, tag)
  return root .. "/" .. M.dir .. "/" .. tag .. ".md"
end

function M.invalidate(root)
  if root then
    cache[root] = nil
  else
    cache = {}
  end
end

-- Returns the sorted list of registered tags and a set for lookups.
function M.registry(root)
  if not cache[root] then
    local list, set = {}, {}
    local dir = root .. "/" .. M.dir
    if vim.fn.isdirectory(dir) == 1 then
      for name, type in vim.fs.dir(dir, { depth = 10 }) do
        local tag = type == "file" and name:match("^(.*)%.md$")
        if tag and M.valid(tag) then
          table.insert(list, tag)
          set[tag] = true
        end
      end
    end
    table.sort(list)
    cache[root] = { list = list, set = set }
  end
  return cache[root].list, cache[root].set
end

function M.exists(root, tag)
  local _, set = M.registry(root)
  return set[tag] == true
end

function M.create(root, tag)
  local path = M.path(root, tag)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile(
      util.load_template(root, "tag", { title = tag }, {
        "---",
        "type: tag",
        "---",
        "# Tag: " .. tag,
        "",
        "What this tag is for: ",
        "",
      }),
      path
    )
  end
  M.invalidate(root)
  return path
end

function M.parse_tag_list(value)
  local items = {}
  for item in (value or ""):gmatch("[^,]+") do
    item = item:gsub('["%[%]]', ""):match("^%s*(.-)%s*$")
    if item ~= "" then
      table.insert(items, item)
    end
  end
  return items
end

-- Line index (1-based) of the closing frontmatter "---", or 0 if there is none.
function M.frontmatter_end(lines)
  if lines[1] ~= "---" then
    return 0
  end
  for i = 2, #lines do
    if lines[i] == "---" then
      return i
    end
  end
  return 0
end

-- Every tag occurrence in the buffer lines, as { tag, lnum, col, end_col }
-- (0-based, end exclusive). Covers frontmatter `tags: [a, b]`, `tags:` YAML
-- lists and inline #tags outside code fences.
function M.scan(lines)
  local found = {}
  local function add(tag, lnum, s, e)
    table.insert(found, { tag = tag, lnum = lnum - 1, col = s - 1, end_col = e - 1 })
  end

  local fm_end = M.frontmatter_end(lines)
  local in_tags_list = false
  for i = 2, fm_end - 1 do
    local line = lines[i]
    local value_start = line:match("^%s*tags:%s*()")
    if value_start then
      in_tags_list = line:sub(value_start) == ""
      for s, word, e in line:sub(value_start):gmatch("()([^,%[%]%s\"']+)()") do
        add(word, i, value_start + s - 1, value_start + e - 1)
      end
    elseif in_tags_list and line:match("^%s*%-") then
      local s, word, e = line:match("^%s*%-%s*[\"']?()([^\"'%s]+)()")
      if s then
        add(word, i, s, e)
      end
    else
      in_tags_list = false
    end
  end

  local in_fence = false
  for i = fm_end + 1, #lines do
    local line = lines[i]
    if line:match("^%s*```") or line:match("^%s*~~~") then
      in_fence = not in_fence
    elseif not in_fence then
      for s, tag, e in line:gmatch("()#([A-Za-z0-9][A-Za-z0-9/_-]*)()") do
        local prev = s > 1 and line:sub(s - 1, s - 1) or ""
        if prev == "" or prev:match("%s") then
          add(tag, i, s, e)
        end
      end
    end
  end
  return found
end

-- Tag under the cursor in the current buffer, if any.
function M.at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  for _, hit in ipairs(M.scan(vim.api.nvim_buf_get_lines(0, 0, -1, false))) do
    if hit.lnum == row - 1 and col >= hit.col and col < hit.end_col then
      return hit.tag
    end
  end
end

-- Usage counts per tag across the vault (frontmatter and inline).
function M.usage(root)
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
    "-g",
    "!" .. M.dir .. "/**",
    root,
  }, { text = true }):wait()
  for line in (result.stdout or ""):gmatch("[^\r\n]+") do
    local items = {}
    if line:sub(1, 1) == "#" then
      items = { line:sub(2) }
    else
      local value = line:match("tags:%s*(.*)$")
      if value and value:match("%[") then
        items = M.parse_tag_list(value:match("%[(.-)%]"))
      end
    end
    for _, tag in ipairs(items) do
      if M.valid(tag) then
        counts[tag] = (counts[tag] or 0) + 1
      end
    end
  end
  return counts
end

return M
