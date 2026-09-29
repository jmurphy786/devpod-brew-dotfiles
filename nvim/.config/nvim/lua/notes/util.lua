local M = {}

M.root = vim.fs.normalize("~/obsidian-vault")

local function in_vault(path)
  return path == M.root or path:sub(1, #M.root + 1) == M.root .. "/"
end

-- The vault root if the buffer's file lives in the vault, else nil.
function M.buf_vault(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr or 0)
  if bufname == "" or bufname == "." then
    return
  end
  if in_vault(vim.fs.normalize(bufname)) then
    return M.root
  end
end

function M.sanitize_title(title)
  title = title:gsub('[\\/:*?"<>|#%[%]]', " ")
  return title:gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function M.load_template(root, name, vars, fallback)
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
    lines = fallback or { "---", "tags: []", "---", "# " .. vars.title, "" }
  end
  return lines
end

return M
